import Foundation
import SecretService
import Logging
import Synchronization

enum KeyringType {
    case service
    case server
}

/// A managed Keyring.
public final class Keyring: Sendable {
    static let logger = Logger(label: "de.amethystsoft.KeyringAccess")
    static let internalQueue = DispatchQueue(label: "de.amethystsoft.KeyringAccess")
    
    public static let appIdentifier = Mutex<String?>(nil)
    static let defaultCollection = Mutex<String?>(nil)
    
    let groupID: String
    let type: KeyringType
    
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
    
    public static func runBatched(
        _ block: @Sendable @escaping (SecretService) async throws -> Void
    ) async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await block(service)
        }
    }
}
