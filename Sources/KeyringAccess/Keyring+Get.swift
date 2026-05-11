import Foundation
import SecretService

extension Keyring {
    public func get(for key: String, service: SecretService? = nil) async throws(SecSError) -> String? {
        try await getString(key, service: service)
    }
    
    
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func get(for key: String) throws(SecSError) -> String? {
        return try bridgeBlocking { () throws(SecSError) -> String? in
            try await self.getString(key)
        }
    }
    
    public func getString(
        _ key: String,
        service: SecretService? = nil
    ) async throws(SecSError) -> String? {
        guard let service else {
            do {
                return try await SecretService.withDefaultConnection { connection -> String? in
                    let service = SecretService(connection: connection)
                    return try await self._getString(key, service: service)
                }
            } catch { throw error.asSecSError }
        }
            
        return try await _getString(key, service: service)
    }
    
    private func _getString(
        _ key: String,
        service: SecretService
    ) async throws(SecSError) -> String? {
        if !service.isConnected {
            try await service.connect()
        }
        
        let defaultCollection = try await self.getRetrieveOrCreateDefaultCollection(service)
        
        guard let item = try await service.searchItems(
            for: self.attributes(for: key),
            in: defaultCollection
        ).first else { return nil }
        
        let secret = try await service.getSecret(of: item)
        
        return String(bytes: secret.value, encoding: .utf8)
    }
}
