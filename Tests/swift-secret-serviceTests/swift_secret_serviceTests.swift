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
        
        //print(alias ?? "No collection for the given alias")
        #expect(alias != nil)
    }
}

@Test func testCreateReadItem() async throws {
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
                .string("service"): .string("de.amethystsoft.swift-secret-service.tests")
            ])
         ]
        
        let (item, prompt) = try await service.createItem(
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
    }
}
