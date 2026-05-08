import Testing
@testable import SecretService

@Suite
struct IETF1024Tests {
    @Test func testPublicKeyIsNotNull() async throws {
        let dh = try IETF1024DH()
        
        #expect(dh.publicKey.contains(where: { $0 != 0 }))
    }
}
