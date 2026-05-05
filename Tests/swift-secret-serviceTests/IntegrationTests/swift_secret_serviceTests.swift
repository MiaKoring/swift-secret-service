import Testing
import Foundation
import DBUS
import CryptoSwift
@testable import SecretService

class IntegrationTests {
    /// Integration tests should set this attribute as string to "1" on temporarily created items
    /// If items are created, the test function should call teardown as last statement in the withDefaultConnection closure
    static let teardownDeleteAttributeName = "swift-secret-service-delete-on-teardown"
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testConnection() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            try await service.connect()
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testReadAlias() async throws {
        try await SecretService.withDefaultConnection { connection in
            let service = SecretService(connection: connection)
            let alias = try await service.readAlias()
            
            #expect(alias != nil)
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
            
            let secret = "test123"
            
            let properties: [String: DBusValue] = [
                "org.freedesktop.Secret.Item.Label": .string("test"),
                "org.freedesktop.Secret.Item.Attributes": .dictionary([
                    .string("service"): .string("de.amethystsoft.swift-secret-service.tests"),
                    .string(Self.teardownDeleteAttributeName): .string("1")
                ])
            ]
            
            let (item, _) = try await service.createItem(
                secret: Secret(value: secret.bytes),
                collection: collection,
                properties: properties
            )
            
            guard let item else {
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
            #expect(value.value == secret.bytes)
            
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
            
            let secret = "test123"
            
            let properties: [String: DBusValue] = [
                "org.freedesktop.Secret.Item.Label": .string("test"),
                "org.freedesktop.Secret.Item.Attributes": .dictionary([
                    .string("service"): .string("de.amethystsoft.swift-secret-service.tests"),
                    .string(Self.teardownDeleteAttributeName): .string("1")
                ])
            ]
            
            let (item, _) = try await service.createItem(
                secret: Secret(value: secret.bytes),
                collection: collection,
                properties: properties
            )
            
            guard let item else {
                Issue.record("Item is unexpectedly nil")
                return
            }
            
            let returnedSecret = try await service.getSecret(of: item)
            #expect(returnedSecret.value == secret.bytes)
            
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
}
