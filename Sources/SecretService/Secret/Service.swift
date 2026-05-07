import DBUS
import Foundation
import CryptoSwift
import Synchronization

enum SecS {
    static let service = "org.freedesktop.secrets"
    static let transferProtocol = "dh-ietf1024-sha256-aes128-cbc-pkcs7"
    
    enum Iface {
        static let service    = "org.freedesktop.Secret.Service"
        static let collection = "org.freedesktop.Secret.Collection"
        static let item       = "org.freedesktop.Secret.Item"
        static let session    = "org.freedesktop.Secret.Session"
        static let prompt     = "org.freedesktop.Secret.Prompt"
    }
}

// Method implementation complete
public final class SecretService: Sendable {
    private let sessionData = Mutex(InternalData())
    
    let connection: DBusServerConnection
    
    var dbusClientConnection: DBusClient.Connection {
        connection as! DBusClient.Connection
    }
    
    public init(connection: DBusServerConnection) {
        self.connection = connection
    }
    
    private struct InternalData: @unchecked Sendable {
        var symmetricKey: [UInt8]?
        var sessionPath: String?
    }
    
    /// Starts an encrypted session using dh-ietf1024-sha256-aes128-cbc-pkcs7
    ///
    /// org.freedesktop.Secret.Service.OpenSession
    public func connect() async throws(SecSError) {
        let dh = IETF1024DH()
        
        let dbusPublicKey = dh.publicKey.map { DBusValue.byte($0) }
        
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
    
    /// Creates a new collection.
    ///
    /// - Parameters:
    ///   - properties: Properties for the collection, e.g. a label
    ///   - alias:
    ///   If creating this collection for a well known alias then a string like default. If an collection with this well-known alias already exists, then that collection will be returned instead of creating a new collection. Any readwrite properties provided to this function will be set on the collection.
    ///
    ///   Set this to nil if the new collection should not be associated with a well known alias.
    /// - Returns:
    ///   - ObjectPath to collection
    ///   - Prompt (only needs to be invoked when item is nil)
    ///
    /// Use of default collection (returned by ``SecretService/readAlias(_:)``) is recommended for most cases.
    /// Ubuntu 26.04 for example only supports the default alias.
    ///
    /// org.freedesktop.Secret.Service.CreateCollection
    public func createCollection(
        properties: [String: DBusValue],
        alias: String?
    ) async throws(SecSError) -> (collection: String?, prompt: String?) {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "CreateCollection",
            body: [
                .dictionary(properties.asStringToVariant),
                .string(alias ?? "")
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeCreateCollection()
    }
    
    /// Unlocks the specified objects
    ///
    /// - Parameters:
    ///   - objects: Array of ObjectPaths of the objects to unlock
    /// - Returns:
    ///   - Array of ObjectPaths of Objects that were unlocked without a prompt
    ///   - ObjectPath to a prompt to unlock the remaining items or nil if no prompt is required
    ///
    /// org.freedesktop.Secret.Service.Unlock
    public func unlock(
        objects: [String]
    ) async throws(SecSError) -> (unlocked: [String], prompt: String?) {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "Unlock",
            body: [
                .array(objects.asDBusObjectPathArray)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeUnlock()
    }
    
    /// Locks the specified objects
    ///
    /// - Parameters:
    ///   - objects: Array of ObjectPaths of the objects to unlock
    /// - Returns:
    ///   - Array of ObjectPaths of Objects that were locked without a prompt
    ///   - ObjectPath to a prompt to lock the remaining items or nil if no prompt is required
    ///
    /// org.freedesktop.Secret.Service.Lock
    public func lock(
        objects: [String]
    ) async throws(SecSError) -> (locked: [String], prompt: String?) {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "Lock",
            body: [
                .array(objects.asDBusObjectPathArray)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeLock()
    }
    
    /// Retrieve multiple secrets from different items at once
    /// - Parameters:
    ///   - items: Array of ObjectPaths of the items to get the ``Secret``s for
    ///   - collection: The ObjectPath of the collection to search in
    /// - Returns:
    ///   - Dictionary of item ObjectPath to Secret
    ///
    /// org.freedesktop.Secret.Service.GetSecrets
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
    
    /// Get the collection for the given alias
    /// - Parameters:
    ///   - name: The alias you want to get the collection for
    /// - Returns:
    ///   - The ObjectPath of the requested collection or nil if it doesn't exist
    ///
    /// Some SecretService implementations (for example Ubuntu 26.04's) might only support default
    ///
    /// org.freedesktop.Secret.Service.ReadAlias
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
    
    /// Sets the alias for the given collection
    /// - Parameters:
    ///   - name: The alias you want to get the collection for.
    ///   - collection: The ObjectPath of the collection.
    ///
    /// Some SecretService implementations (for example Ubuntu 26.04's) might only support default
    ///
    /// org.freedesktop.Secret.Service.ReadAlias
    public func setAlias(
        _ name: String,
        collection: String
    ) async throws(SecSError) {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: SecS.service.asDBusPath,
            interface: SecS.Iface.service,
            method: "SetAlias",
            body: [
                .string(name),
                .objectPath(collection)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        guard
            response.messageType != .error
        else {
            throw .returnedError(response.body[0, nil]?.string)
        }
    }
    
    /// Sends the request on the current connection and converts errors
    func send(_ request: DBusRequest) async throws(SecSError) -> DBusMessage? {
        do {
            return try await connection.send(request)
        } catch {
            throw .sendingFailed(error)
        }
    }
    
    func getSession() throws(SecSError) -> (session: String, key: [UInt8]) {
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
    
    public static func withDefaultConnection<R: Sendable>(
        _ block: @escaping @Sendable (DBusServerConnection) async throws -> R
    ) async throws -> R {
        return try await DBusClient.withSessionBus(auth: .external(userID: "\(getuid().description)")) { connection in
            return try await block(connection)
        }
    }
}
