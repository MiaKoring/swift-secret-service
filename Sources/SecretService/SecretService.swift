import DBUS
import Foundation
import CryptoSwift
import Synchronization

private enum SecS {
    static let service = "org.freedesktop.secrets"
    static let transferProtocol = "dh-ietf1024-sha256-aes128-cbc-pkcs7"
    
    enum Iface {
        static let service    = "org.freedesktop.Secret.Service"
        static let collection = "org.freedesktop.Secret.Collection"
        static let item       = "org.freedesktop.Secret.Item"
        static let session    = "org.freedesktop.Secret.Session"
    }
}

public final class SecretService: Sendable {
    private let sessionData = Mutex(InternalData())
    
    private let connection: DBusServerConnection
    
    public init(connection: DBusServerConnection) {
        self.connection = connection
    }
    
    private struct InternalData: @unchecked Sendable {
        var symmetricKey: [UInt8]?
        var sessionPath: String?
    }
    
    /// Start a session
    public func connect() async throws(SecSError) {
        let dh = IETF1024DH()
        
        let dbusPublicKey = dh.publicKey.map { DBusValue.byte($0) }
        
        // Method signature: OpenSession(String algorithm, Variant input) -> (Variant output, ObjectPath result)
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "OpenSession",
            body: [
                .string(SecS.transferProtocol),
                .variant(.init(.array(dbusPublicKey)))
            ]
        )
        
        guard let reply = try await send(request) else { throw .noResponse }
        
        let (publicKey, sessionPath) = try reply.decodeOpenSession()
        
        try self.sessionData.withLock { sessionData throws(SecretServiceError) in
            sessionData.symmetricKey = try dh.aesKey(with: publicKey)
            sessionData.sessionPath = sessionPath
        }
    }
    
    /// Get the collection for the given alias
    public func readAlias(_ name: String = "default") async throws(SecSError) -> String? {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "ReadAlias",
            body: [
                .string(name)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeReadAlias()
    }
    
    /// Stores a secret
    public func createItem(
        secret: Secret,
        collection: String,
        properties: [String: DBusValue]
    ) async throws(SecSError) -> (item: String?, prompt: String?) {
        let (session, symmetricKey) = try getSession()
        
        let (encryptedValue, iv) = try AES.encryptAES128PKCS7(
            data: secret.value,
            key: symmetricKey
        )
        
        let secret = DBusValue.secret(
            session: session,
            parameters: iv,
            value: encryptedValue,
            contentType: secret.contentType
        )
        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: collection,
            interface: SecS.Iface.collection,
            method: "CreateItem",
            body: [
                .dictionary(properties.asStringToVariant),
                secret,
                .boolean(true)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeCreateItem()
    }
    
    /// Retrieve multiple secrets from different items at once
    public func getSecrets(
        items: [String],
        collection: String
    ) async throws(SecSError) -> [String: Secret] {
        let (session, symmetricKey) = try getSession()
        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "GetSecrets",
            body: [
                .array(items.asDBusObjectPathArray),
                .objectPath(session)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeGetSecrets(with: symmetricKey)
    }
    
    public static func withDefaultConnection<R: Sendable>(
        _ block: @escaping @Sendable (DBusServerConnection) async throws -> R
    ) async throws -> R {
        return try await DBusClient.withSessionBus(auth: .external(userID: "\(getuid().description)")) { connection in
            return try await block(connection)
        }
    }
    
    /// Sends the request on the current connection and converts errors
    private func send(_ request: DBusRequest) async throws(SecretServiceError) -> DBusMessage? {
        do {
            return try await connection.send(request)
        } catch {
            throw .sendingFailed(error)
        }
    }
    
    private func getSession() throws(SecSError) -> (session: String, key: [UInt8]) {
        return try sessionData.withLock { data throws(SecSError) in
            guard
                let session = data.sessionPath,
                let symmetricKey = data.symmetricKey
            else {
                throw .noActiveSession
            }
            
            return (session, symmetricKey)
        }
    }
}
