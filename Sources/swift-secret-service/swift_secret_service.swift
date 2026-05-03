import DBUS
import Foundation
import CryptoSwift
import Synchronization

private enum SecS {
    static let service = "org.freedesktop.secrets"
    
    enum Iface {
        static let service    = "org.freedesktop.Secret.Service"
        static let collection = "org.freedesktop.Secret.Collection"
        static let item       = "org.freedesktop.Secret.Item"
        static let session    = "org.freedesktop.Secret.Session"
    }
}

extension String {
    var asPath: String {
        self.replacingOccurrences(of: ".", with: "/")
    }
}

public final class SecretService: Sendable {
    private let sessionData = Mutex(InternalData())
    
    private struct InternalData: @unchecked Sendable {
        var symmetricKey: [UInt8]?
        var sessionPath: String?
    }
    
    func connect() async throws {
        try await DBusClient.withSessionBus(auth: .external(userID: "\(getuid().description)")) { connection in
            let dh = IETF1024DH()
            
            let dbusPublicKey = dh.publicKey.map { DBusValue.byte($0) }
            
            // Method signature: OpenSession(String algorithm, Variant input) -> (Variant output, ObjectPath result)
            let request = DBusRequest.createMethodCall(
                destination: "org.freedesktop.secrets",
                path: "/org/freedesktop/secrets",
                interface: "org.freedesktop.Secret.Service",
                method: "OpenSession",
                body: [
                    .string("dh-ietf1024-sha256-aes128-cbc-pkcs7"),
                    .variant(.init(.array(dbusPublicKey)))
                ]
            )
            
            guard let reply = try await connection.send(request) else {
                print("No response from Secret Service")
                return
            }
            
            guard let (publicKey, sessionPath) = reply.decodeOpenSession() else {
                print("OpenSession failed")
                return
            }
            
            self.sessionData.withLock { sessionData in
                sessionData.symmetricKey = dh.aesKey(with: publicKey)
                sessionData.sessionPath = sessionPath
            }
            
            print("connection established")
        }
    }
    
}

extension DBusMessage {
    func decodeOpenSession() -> (publicKey: [UInt8], sessionPath: String)? {
        if
            case .methodReturn = self.messageType,
            body.count >= 2,
            let bobPublic = body[0].array?.asByteArray,
            let sessionPath = body[1].objectPath
        {
            return (publicKey: bobPublic, sessionPath: sessionPath)
        } else if case .error = self.messageType {
            print(body)
        } else {
            print("An unexpected error occurred")
        }
        return nil
    }
}

extension Array where Element == DBusValue {
    /// Tries to convert [DBusValue] to [UInt8]
    /// Returns nil if the array contains something not a byte
    var asByteArray: [UInt8]? {
        var result = [UInt8]()
        
        for element in self {
            guard let byte = element.byte else {
                print("found unexpected type")
                return nil
            }
            
            result.append(byte)
        }
        
        return result
    }
}
