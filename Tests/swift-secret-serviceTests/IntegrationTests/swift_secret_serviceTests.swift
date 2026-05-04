import Testing
import Foundation
import DBUS
import CryptoSwift
@testable import SecretService

class IntegrationTests {
    /// Integration tests should set this attribute as string to "1" on temporarily created items
    /// They will be deleted in deinit in the future
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
            
            //print(alias ?? "No collection for the given alias")
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
            
            /*
             print("item: \(item ?? "[no item]")")
             print("prompt: \(item ?? "[no prompt required]")")
             */
            
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
