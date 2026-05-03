import Testing
@testable import swift_secret_service

@Test func testConnection() async throws {
    let service = SecretService()
    try await service.connect()
}
