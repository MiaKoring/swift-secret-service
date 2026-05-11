import Foundation
import SecretService

extension Keyring {
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public subscript(data key: String) -> Data? {
        get {
            do {
                return try getData(for: key)
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
                try setData(newValue, for: key)
            } catch {
                Self.logger.error(
                    "Encountered error while getting data via subscript",
                    error: error
                )
            }
        }
    }
    
    public subscript(asyncData key: String) -> Data? {
        get async throws(SecSError) {
            do {
                return try await getData(key)
            } catch {
                Self.logger.error(
                    "Encountered error while getting data via subscript",
                    error: error
                )
                return nil
            }
        }
    }
    
   @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    public func getData(for key: String) throws(SecSError) -> Data? {
        return try bridgeBlocking { () throws(SecSError) -> Data? in
            try await self.getData(key)
        }
    }
    
    public func getData(
        _ key: String,
        service: SecretService? = nil
    ) async throws(SecSError) -> Data? {
        guard let service else {
            do {
                return try await SecretService.withDefaultConnection { connection -> Data? in
                    let service = SecretService(connection: connection)
                    return try await self._getData(key, service: service)
                }
            } catch { throw error.asSecSError }
        }
        
        return try await _getData(key, service: service)
    }
    
    private func _getData(
        _ key: String,
        service: SecretService
    ) async throws(SecSError) -> Data? {
        if !service.isConnected {
            try await service.connect()
        }
        
        let defaultCollection = try await self.getRetrieveOrCreateDefaultCollection(service)
        
        guard let item = try await service.searchItems(
            for: self.attributes(for: key),
            in: defaultCollection
        ).first else { return nil }
        
        let secret = try await service.getSecret(of: item)
        
        return Data(secret.value)
    }
}
