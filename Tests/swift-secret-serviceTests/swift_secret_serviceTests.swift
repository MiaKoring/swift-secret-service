import Testing
import DBUS
@testable import SecretService

@Test func testConnection() async throws {
    try await SecretService.withDefaultConnection { connection in
        let service = SecretService(connection: connection)
        try await service.connect()
    }
}

@Test func testReadAlias() async throws {
    try await SecretService.withDefaultConnection { connection in
        let service = SecretService(connection: connection)
        let alias = try await service.readAlias()
        
        print(alias ?? "No collection for the given alias")
        #expect(alias != nil)
    }
}

@Test func testCreateItem() async throws {
    try await SecretService.withDefaultConnection { connection in
        let service = SecretService(connection: connection)
        try await service.connect()
        
        guard let collection = try await service.readAlias() else {
            Issue.record("no default collection found")
            return
        }
        
        let properties: [String: DBusValue] = [
            "org.freedesktop.Secret.Item.Label": .string("test"),
            "org.freedesktop.Secret.Item.Attributes": .dictionary([
                .string("service"): .string("de.amethystsoft.swift-secret-service.tests")
            ])
         ]
        
        let (item, prompt) = try await service.storeItem(
            value: "test123".bytes,
            collection: collection,
            properties: properties
        )
        
        print("item: \(item ?? "[no item]")")
        print("prompt: \(item ?? "[no prompt required]")")
    }
}
