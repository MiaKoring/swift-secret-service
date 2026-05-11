import Foundation
import SecretService

extension Keyring {
    func getRetrieveOrCreateDefaultCollection(_ service: SecretService? = nil) async throws(SecSError) -> String {
        // If we already know the defaultCollection, just return it
        if let defaultCollection = Self.defaultCollection.withLock({ $0 }) {
            return defaultCollection
        }
        
        do {
            guard let service else {
                return try await SecretService.withDefaultConnection { connection in
                    let service = SecretService(connection: connection)
                    return try await self.retrieveOrCreateDefaultCollection(with: service)
                }
            }
            return try await self.retrieveOrCreateDefaultCollection(with: service)
        } catch { throw error.asSecSError }
    }
    
    func retrieveOrCreateDefaultCollection(with service: SecretService) async throws(SecSError) -> String {
        // Return if a default collection is set on the service already
        if let defaultCollection = try await service.readAlias() {
            return defaultCollection
        }
        
        // Get all existing collections
        guard
            let collections = try await service.readProperty(
                "Collections",
                interface: SecS.service
            ).array?.asObjectPathArray
        else {
            throw SecSError.unexpectedResponse(for: "Read property Collections")
        }
        
        // If there already is a login collection, set it as default & return
        if let login = collections.first(where: { $0 .hasSuffix("/login")}) {
            try await service.setAlias("default", collection: login)
            return self.setDefaultCollection(to: login)
        } else {
            // Create login collection as default
            let (collection, prompt) = try await service.createCollection(
                properties: [
                    "org.freedesktop.Secret.Collection.Label": .string("login")
                ],
                alias: "default"
            )
            
            // Return immediately if no prompt is required
            if let collection {
                return self.setDefaultCollection(to: collection)
            } else if let prompt {
                // Show prompt if needed
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
                // Set and return prompt result
                return self.setDefaultCollection(to: collection)
            } else {
                throw SecSError.unexpectedResponse(for: "CreateCollection")
            }
        }
    }
    
    func setDefaultCollection(to defaultCollection: String) -> String {
        Keyring.defaultCollection.withLock { collection in
            collection = defaultCollection
        }
        return defaultCollection
    }
    
    @available(*, noasync, message: "Do not use the synchronous API of 'Keyring' in async contexts to avoid deadlocks.")
    func bridgeBlocking<R: Sendable, E: Error>(
        _ block: @escaping @Sendable () async throws(E) -> R
    ) throws(E) -> R {
        
        let semaphore = DispatchSemaphore(value: 0)
        let result: MutableBox<Result<R, E>?> = MutableBox(nil)
        
        Self.internalQueue.async {
            Task { [result] in
                do {
                    let blockResult = try await block()
                    result.value = .success(blockResult)
                } catch let error as E {
                    result.value = .failure(error)
                }
                
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        switch result.value {
            case .success(let result): return result
            case .failure(let error): throw error
            // Should be impossible
            case .none:
                fatalError("Unexpectedly reached nil in Keyring.bridgeBlocking")
        }
    }
    
    func attributes(for key: String) -> [String: String] {
        guard
            let appIdentifier = Self.appIdentifier.withLock({ $0 })
        else {
            fatalError("Unexpectedly found nil Keyring.appIdentifier. Make sure to set your AppIdentifier before using KeyringAccess")
        }
        
        return [
            "xdg:schema": "org.freedesktop.Secret.Generic",
            "account": key,
            self.type == .service ? "service" : "server": self.groupID,
            "appID": appIdentifier
        ]
    }
    
    func dbusAttributes(for key: String) -> DBusValue {
        guard
            let appIdentifier = Self.appIdentifier.withLock({ $0 })
        else {
            fatalError("Unexpectedly found nil Keyring.appIdentifier. Make sure to set your AppIdentifier before using KeyringAccess")
        }
        
        return .dictionary([
            .string("xdg:schema"): .string("org.freedesktop.Secret.Generic"),
            .string("account"): .string(key),
            .string(self.type == .service ? "service" : "server"): .string(self.groupID),
            .string("appID"): .string(appIdentifier)
        ])
    }
    
    class MutableBox<T: Sendable>: @unchecked Sendable {
        var value: T
        init(_ value: T) {
            self.value = value
        }
    }
}
