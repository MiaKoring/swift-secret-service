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
        
        try await keyring.set(secret, for: key)
        let result = try await keyring.get(for: key)
        
        #expect(result == secret)
        
        let newSecret = "321tseT"
        
        try await keyring.set(newSecret, for: key)
        let newResult = try await keyring.get(for: key)
        
        #expect(newResult == newSecret)
        
        try await keyring.set(nil, for: key)
        let deletedResult = try await keyring.get(for: key)
        
        #expect(deletedResult == nil)
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
