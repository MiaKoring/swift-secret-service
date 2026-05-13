import Foundation
import SecretService
import Logging
import Synchronization

enum KeyringType {
    case service
    case server
}

/// A managed Keyring.
public struct Keyring: @unchecked Sendable {
    static let logger = Logger(label: "de.amethystsoft.KeyringAccess")
    static let internalQueue = DispatchQueue(label: "de.amethystsoft.KeyringAccess")
    
    public static let appIdentifier = Mutex<String?>(nil)
    static let defaultCollection = AsyncMutex<String?>(value: nil)
    
    let groupID: String
    let type: KeyringType
    
    var label: String?
    
    /// - Parameters:
    ///   - service: The service the Keyring should store secrets for.
    ///     e.g. de.amethystsoft.KeyringAccess
    public init(service: String) {
        self.groupID = service
        self.type = .service
    }
    
    /// - Parameters:
    ///   - service: The server the Keyring should store secrets for.
    ///     e.g. "https://amethystsoft.de"
    public init(server: String) {
        self.groupID = server
        self.type = .server
    }
    
    /// Run multiple operations using the same connection, saving the connection establishment cost.
    ///
    /// This only works with functions you pass the connection (SecretService), not subscripts.
    ///
    /// Only asynchronous methods are available in this block.
    ///
    /// - Parameters:
    ///   - block: The code to execute with the shared connection.
    public static func runBatched(
        _ block: @Sendable @escaping (SecretService) async throws -> Void
    ) async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await block(service)
        }
    }
    
    public func label(_ label: String) -> Self {
        var new = self
        new.label = label
        return new
    }
}
