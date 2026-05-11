import Foundation
import SecretService

extension Keyring {
    /// Set a the string for the given key and handle potential errors.
    ///
    /// Can re-use a shared connection.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - key: The key for the secret. For example an account name.
    ///   - service: The shared, already established connection (or nil).
    public func set(
        _ value: String?,
        for key: String,
        service: SecretService? = nil
    ) async throws(SecSError) {
        guard let service else {
            do {
                return try await SecretService.withDefaultConnection { connection in
                    let service = SecretService(connection: connection)
                    try await self._set(value?.bytes, for: key, service: service)
                }
            } catch { throw error.asSecSError }
        }
        
        return try await _set(value?.bytes, for: key, service: service)
    }
    
    /// Set a the string for the given key and handle potential errors.
    ///
    /// Unavailable in asynchronous contexts. Use async counterpart.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - key: The key for the secret. For example an account name.
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func set(_ value: String?, for key: String) throws(SecSError) {
        return try bridgeBlocking { () throws(SecSError) in
            try await self.set(value, for: key, service: nil)
        }
    }
    
    /// Set data for the given key and handle potential errors.
    ///
    /// Can re-use a shared connection.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - key: The key for the secret. For example an account name.
    ///   - service: The shared, already established connection (or nil).
    public func setData(
        _ value: Data?,
        for key: String,
        service: SecretService? = nil
    ) async throws(SecSError) {
        guard let service else {
            do {
                return try await SecretService.withDefaultConnection { connection in
                    let service = SecretService(connection: connection)
                    try await self._set(value?.byteArray, for: key, service: service)
                }
            } catch { throw error.asSecSError }
        }
        
        return try await _set(value?.byteArray, for: key, service: service)
    }
    
    /// Set data for the given key and handle potential errors.
    ///
    /// Unavailable in asynchronous contexts. Use async counterpart.
    ///
    /// - Parameters:
    ///   - value: The new value.
    ///   - key: The key for the secret. For example an account name.
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func setData(_ value: Data?, for key: String) throws(SecSError) {
        return try bridgeBlocking { () throws(SecSError) in
            try await self.setData(value, for: key, service: nil)
        }
    }
    
    private func _set(
        _ value: [UInt8]?,
        for key: String,
        service: SecretService
    ) async throws(SecSError) {
        guard let value else {
            try await _deleteItem(with: key, service: service)
            return
        }
        
        if !service.isConnected {
            try await service.connect()
        }
        
        let defaultCollection = try await self.getRetrieveOrCreateDefaultCollection(service)
        
        let secret = Secret(value: value)
        
        let (item, prompt) = try await service.createItem(
            secret: secret,
            collection: defaultCollection,
            properties: [
                // TODO: Label
                "org.freedesktop.Secret.Item.Attributes": dbusAttributes(for: key)
            ]
        )
        
        // Early return if no prompt is needed
        guard
            item == nil,
            let prompt
        else { return }
        
        try await service.prompt(prompt, windowID: nil)
        let result = try await service.awaitPromptCompleted(for: prompt)
        
        guard
            result?.dismissed == false,
            let collection = result?.result.objectPath
        else {
            if result?.dismissed == false {
                throw SecSError.promptDismissed
            } else {
                throw SecSError.noResponse
            }
        }
    }
    
    private func _deleteItem(
        with key: String,
        service: SecretService
    ) async throws(SecSError) {
        if !service.isConnected {
            try await service.connect()
        }
        
        let defaultCollection = try await self.getRetrieveOrCreateDefaultCollection(service)
        
        guard let item = try await service.searchItems(
            for: attributes(for: key),
            in: defaultCollection
        ).first else { return }
        
        guard let prompt = try await service.deleteItem(item: item) else { return }
        
        try await service.prompt(prompt, windowID: nil)
        let result = try await service.awaitPromptCompleted(for: prompt)
        
        guard
            result?.dismissed == false,
            let deletedItem = result?.result.objectPath
        else {
            if result?.dismissed == false {
                throw SecSError.promptDismissed
            } else {
                throw SecSError.noResponse
            }
        }
        
        if deletedItem != item {
            throw SecSError.unexpectedResponse(
                for: "Delete item prompt returned different ObjectPath than expected"
            )
        }
    }
}
