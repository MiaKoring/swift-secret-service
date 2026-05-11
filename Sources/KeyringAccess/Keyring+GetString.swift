import Foundation
import SecretService

extension Keyring {
    /// Get or set a string for the given key.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///
    ///   Example usage:
    ///   keychain["test"] = newValue
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public subscript(_ key: String) -> String? {
        get {
            do {
                return try get(for: key)
            } catch {
                Self.logger.error(
                    "Encountered error while getting data via subscript",
                    error: error
                )
                return nil
            }
        }
        set {
            do {
                try set(newValue, for: key)
            } catch {
                Self.logger.error(
                    "Encountered error while getting data via subscript",
                    error: error
                )
            }
        }
    }
    
    /// Get the string for the given key asynchronously and handle potential errors.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///
    ///   Example usage:
    ///   let secret = try await keychain[asyncString: "test"]
    public subscript(asyncString key: String) -> String? {
        get async throws(SecSError) {
            return try await get(for: key)
        }
    }
    
    /// Get the string for the given key and handle potential errors.
    ///
    /// Can re-use a shared connection.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///   - service: The shared, already established connection (or nil).
    public func get(for key: String, service: SecretService? = nil) async throws(SecSError) -> String? {
        try await getString(key, service: service)
    }
    
    /// Get the string for the given key and handle potential errors.
    ///
    /// Unavaliable in asynchronous contexts. Use async counterpart.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func get(for key: String) throws(SecSError) -> String? {
        return try bridgeBlocking { () throws(SecSError) -> String? in
            try await self.getString(key)
        }
    }
    
    /// Get the string for the given key and handle potential errors.
    ///
    /// Can re-use a shared connection.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///   - service: The shared, already established connection (or nil).
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
