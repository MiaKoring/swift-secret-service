import SecretService
import Foundation

public struct Attributes: Sendable {
    public let label: String
    public let created: Date
    public let modified: Date
}

extension Keyring {
    /// Get the attributes for the given key.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///
    ///   Example usage:
    ///   let attr = keychain[attributes: "test"]
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public subscript(attributes key: String) -> Attributes? {
        get {
            do {
                return try getAttributes(for: key)
            } catch {
                Self.logger.error(
                    "Encountered error while getting data via subscript",
                    error: error
                )
                return nil
            }
        }
    }
    
    /// Get the attributes for the given key.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///
    ///   Example usage:
    ///   let attr = keychain[asyncAttributes: "test"]
    public subscript(asyncAttributes key: String) -> Attributes? {
        get async throws(SecSError) {
            return try await getAttributes(key)
        }
    }
    
    /// Get attributes for the given key and handle potential errors.
    ///
    /// Unavaliable in asynchronous contexts. Use async counterpart.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func getAttributes(for key: String) throws(SecSError) -> Attributes? {
        return try bridgeBlocking { () throws(SecSError) -> Attributes? in
            try await self.getAttributes(key)
        }
    }
    
    /// Get attributes for the given key and handle potential errors.
    ///
    /// Can re-use a shared connection.
    ///
    /// - Parameters:
    ///   - key: The key for the secret. For example an account name.
    ///   - service: The shared, already established connection (or nil).
    public func getAttributes(
        _ key: String,
        service: SecretService? = nil
    ) async throws(SecSError) -> Attributes? {
        guard let service else {
            do {
                return try await SecretService.withDefaultConnection { connection -> Attributes? in
                    let service = SecretService(connection: connection)
                    return try await self._getAttributes(key, service: service)
                }
            } catch { throw error.asSecSError }
        }
        
        return try await _getAttributes(key, service: service)
    }
    
    private func _getAttributes(
        _ key: String,
        service: SecretService
    ) async throws(SecSError) -> Attributes? {
        if !service.isConnected {
            try await service.connect()
        }
        
        let defaultCollection = try await self.getRetrieveOrCreateDefaultCollection(service)
        
        guard let item = try await service.searchItems(
            for: self.attributes(for: key),
            in: defaultCollection
        ).first else { return nil }
        
        guard
            let label = try await service.readProperty(
            "Label",
            interface: SecS.Iface.item,
            object: item
            ).string,
            let created = try await service.readProperty(
                "Created",
                interface: SecS.Iface.item,
                object: item
            ).uint64,
            let modified = try await service.readProperty(
                "Modified",
                interface: SecS.Iface.item,
                object: item
            ).uint64
        else { return nil }
        
        return Attributes(
            label: label,
            created: Date(timeIntervalSince1970: Double(created)),
            modified: Date(timeIntervalSince1970: Double(modified))
        )
    }
}
