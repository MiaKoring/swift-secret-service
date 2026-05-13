import Foundation
import Testing
@testable import KeyringAccess

@Suite(.serialized)
struct KeyringTest {
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testCRUD() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123"
        
        try await Keyring.runBatched { service in
            try await keyring.set(secret, for: key, service: service)
            let result = try await keyring.get(for: key, service: service)
            
            #expect(result == secret)
            
            let newSecret = "321tseT"
            
            try await keyring.set(newSecret, for: key, service: service)
            let newResult = try await keyring.get(for: key, service: service)
            
            #expect(newResult == newSecret)
            
            try await keyring.set(nil, for: key, service: service)
            let deletedResult = try await keyring.get(for: key, service: service)
            
            #expect(deletedResult == nil)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testSubscriptCRUD() {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        var keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123"
        
        keyring[key] = secret
        let result = keyring[key]
        
        #expect(result == secret)
        
        let newSecret = "321tseT"
        
        keyring[key] = newSecret
        let newResult = keyring[key]
        
        #expect(newResult == newSecret)
        
        keyring[key] = nil
        let deletedResult = keyring[key]
        
        #expect(deletedResult == nil)
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testAsyncThrowingSubscriptGetter() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123"
        
        try await keyring.set(secret, for: key)
        
        let result = try await keyring[asyncString: key]
        
        #expect(result == secret)
        
        try await keyring.set(nil, for: key)
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testCRUDData() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123".data(using: .utf8)
        
        try await Keyring.runBatched { service in
            try await keyring.setData(secret, for: key, service: service)
            let result = try await keyring.getData(key, service: service)
            
            #expect(result == secret)
            
            let newSecret = "321tseT".data(using: .utf8)
            
            try await keyring.setData(newSecret, for: key, service: service)
            let newResult = try await keyring.getData(key, service: service)
            
            #expect(newResult == newSecret)
            
            try await keyring.set(nil, for: key, service: service)
            let deletedResult = try await keyring.getData(key, service: service)
            
            #expect(deletedResult == nil)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testSubscriptCRUDData() {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        var keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123".data(using: .utf8)
        
        keyring[data: key] = secret
        let result = keyring[data: key]
        
        #expect(result == secret)
        
        let newSecret = "321tseT".data(using: .utf8)
        
        keyring[data: key] = newSecret
        let newResult = keyring[data: key]
        
        #expect(newResult == newSecret)
        
        keyring[data: key] = nil
        let deletedResult = keyring[data: key]
        
        #expect(deletedResult == nil)
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testAsyncThrowingSubscriptGetterData() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
        let key = "test"
        let secret = "Test123".data(using: .utf8)
        
        try await keyring.setData(secret, for: key)
        
        let result = try await keyring[asyncData: key]
        
        #expect(result == secret)
        
        try await keyring.setData(nil, for: key)
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testLabel() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let label = "KeyringAccess Test"
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
            .label(label)
        let key = "test"
        let secret = "Test123"
        
        try await Keyring.runBatched { service in
            try await keyring.set(secret, for: key, service: service)
            let attributes = try await keyring[asyncAttributes: key]
            
            #expect(attributes?.label == label)
            
            let newSecret = "321tseT"
            let newLabel = "KeyringAccess Test 2"
            let newKeyring = keyring.label(newLabel)
            
            try await newKeyring.set(newSecret, for: key, service: service)
            let newAttributes = try await newKeyring[asyncAttributes: key]
            
            #expect(newAttributes?.label == newLabel)
            
            try await keyring.set(nil, for: key, service: service)
        }
    }
    
    @Test(.enabled(if: ProcessInfo.runIntegrationTests))
    func testAttributes() async throws {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.KeyringAccess.Testing"
        }
        
        let label = "KeyringAccess Test"
        let keyring = Keyring(service: "de.amethystsoft.KeyringAccess.Testing")
            .label(label)
        let key = "test"
        let secret = "Test123"
        
        try await Keyring.runBatched { service in
            let creationTime = Date()
            try await keyring.set(secret, for: key, service: service)
            let attributes = try await keyring[asyncAttributes: key]
            
            #expect(attributes?.label == label)
            
            let newSecret = "321tseT"
            let newLabel = "KeyringAccess Test 2"
            let newKeyring = keyring.label(newLabel)
            
            let editTime = Date()
            try await newKeyring.set(newSecret, for: key, service: service)
            guard let newAttributes = try await newKeyring[asyncAttributes: key] else {
                Issue.record("No attributes for the given key")
                return
            }
            
            #expect(newAttributes.label == newLabel)
            #expect(
                newAttributes.created.timeIntervalSince1970
                - creationTime.timeIntervalSince1970
                <= 1.5
            )
            #expect(
                newAttributes.modified.timeIntervalSince1970
                - editTime.timeIntervalSince1970
                <= 1.5
            )
            
            try await keyring.set(nil, for: key, service: service)
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
