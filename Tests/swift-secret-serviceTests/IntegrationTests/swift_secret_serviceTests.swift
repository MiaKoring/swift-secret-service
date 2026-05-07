import Testing
import Foundation
import DBUS
import CryptoSwift
import Logging
@testable import SecretService

@Suite(.serialized)
struct IntegrationTests: Sendable {
    /// Integration tests should set this attribute as string to "1" on temporarily created items
    /// If items are created, the test function should call teardown as last statement in the withDefaultConnection closure
    static let teardownDeleteAttributeName = "swift-secret-service-delete-on-teardown"
    static let testSecret = "test123"
    let logger = Logger(label: "IntegrationTests")
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testConnection() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
            try await service.disconnect()
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testReadSetAlias() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            
            guard let collection = try await service.readAlias() else {
                Issue.record("collection was unexpectedly nil")
                return
            }
            
            try await service.setAlias("default", collection: collection)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testCreateReadDeleteItem() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
            
            guard let collection = try await service.readAlias() else {
                Issue.record("no default collection found")
                return
            }
            
            guard let item = try await createTestItem(using: service, in: collection) else {
                Issue.record("Item is unexpectedly nil")
                return
            }
            
            let secrets = try await service.getSecrets(items: [item], collection: collection)
            
            guard
                let (key, value) = secrets.first,
                secrets.count == 1
            else {
                Issue.record("Mismatch between amount of expected secrets and returned secrets")
                return
            }
            
            #expect(key == item)
            #expect(value.value == Self.testSecret.bytes)
            
            try await Self.teardown(collection: collection, service: service)
            
            let itemsAfterDelete = try await service.searchItems(
                for: [Self.teardownDeleteAttributeName: "1"],
                in: collection
            )
            
            #expect(itemsAfterDelete.isEmpty)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testGetSetSecret() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
            
            guard let collection = try await service.readAlias() else {
                Issue.record("no default collection found")
                return
            }
            
            guard let item = try await createTestItem(using: service, in: collection) else {
                Issue.record("Item is unexpectedly nil")
                return
            }
            
            let returnedSecret = try await service.getSecret(of: item)
            #expect(returnedSecret.value == Self.testSecret.bytes)
            
            let newSecret = "newSecret"
            
            try await service.setSecret(
                on: item,
                secret: Secret(value: newSecret.bytes)
            )
            
            let newReturnedSecret = try await service.getSecret(of: item)
            #expect(newReturnedSecret.value == newSecret.bytes)
            
            try await Self.teardown(collection: collection, service: service)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests && ProcessInfo.doPrompting))
    func testCreateDeleteCollection() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
            
            let result = try await service.createCollection(
                properties: [
                    "org.freedesktop.Secret.Collection.Label": .string("TestCollection")
                ],
                alias: ""
            )
            
            var collection: String? = result.collection
            
            if
                collection == nil,
                let prompt = result.prompt
            {
                logger.info("Should show prompt for creation of collection")
                try await service.prompt(prompt, windowID: nil)
                
                guard let result = try await service.awaitPromptCompleted() else {
                    throw SecSError.noResponse
                }
                
                if result.dismissed {
                    logger.info("Prompt dismissed")
                    return
                }
                collection = result.result.objectPath
            }
            
            guard let collection else {
                logger.warning("Prompt must be completed to continue testing")
                return
            }
            
            logger.info("Collection created successfully")
            
            if let prompt = try await service.deleteCollection(collection) {
                logger.info("Should show prompt for deletion of collection")
                try await service.prompt(prompt, windowID: nil)
                guard let result = try await service.awaitPromptCompleted() else {
                    throw SecSError.noResponse
                }
                if result.dismissed {
                    logger.info("Prompt dismissed")
                    logger.warning(
                        "Completion of the prompt is required to delete the collection"
                    )
                }
            }
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests && ProcessInfo.doPrompting))
    func testLockUnlock() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
                       
            guard let collection = try await service.readAlias() else {
                Issue.record("Unexpectedly readAlias for default returned nil")
                return
            }
            
            let lockResult = try await service.lock(objects: [collection])
            
            if let prompt = lockResult.prompt {
                logger.info("Should show prompt for locking of collection")
                
                try await service.prompt(prompt, windowID: nil)
                guard let result = try await service.awaitPromptCompleted() else {
                    throw SecSError.noResponse
                }
                
                guard !result.dismissed else {
                    logger.warning(
                        "Completion of the prompt is required to lock the collection"
                    )
                    return
                }
                #expect(result.result.array?.asObjectPathArray == [collection])
            }
            
            let unlockResult = try await service.unlock(objects: [collection])
            
            if let prompt = unlockResult.prompt {
                logger.info("Should show prompt for unlocking of collection")
                
                try await service.prompt(prompt, windowID: nil)
                guard let result = try await service.awaitPromptCompleted() else {
                    throw SecSError.noResponse
                }
                
                guard !result.dismissed else {
                    logger.warning(
                        "Completion of the prompt is required to unlock the item"
                    )
                    return
                }
                #expect(result.result.array?.asObjectPathArray == [collection])
            }
        }
    }
    
    private func createTestItem(
        using service: SecretService,
        in collection: String
    ) async throws -> String? {
        let properties: [String: DBusValue] = [
            "org.freedesktop.Secret.Item.Label": .string("test"),
            "org.freedesktop.Secret.Item.Attributes": .dictionary([
                .string("service"): .string("de.amethystsoft.swift-secret-service.tests"),
                .string(Self.teardownDeleteAttributeName): .string("1")
            ])
        ]
        
        let (item, _) = try await service.createItem(
            secret: Secret(value: Self.testSecret.bytes),
            collection: collection,
            properties: properties
        )
        
        return item
    }
    
    static func teardown(collection: String, service: SecretService) async throws {
        let items = try await service.searchItems(
            for: [Self.teardownDeleteAttributeName: "1"],
            in: collection
        )
        
        for item in items {
            _ = try await service.deleteItem(item: item)
        }
    }
}

extension ProcessInfo {
    static var runIntegrationTests: Bool {
        ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1"
    }
    
    /// Use to only run a test in an environment supporting prompting.
    static var doPrompting: Bool {
        ProcessInfo.processInfo.environment["EVALUATE_PROMPTS"] == "1"
    }
}
