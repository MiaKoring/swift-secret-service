import CryptoSwift

public typealias SecSError = SecretServiceError

public enum SecretServiceError: Error {
    // MARK: - DBus Request
    case sendingFailed(Error)
    
    // MARK: - Invalid order of invocation
    case noActiveSession
    
    // MARK: - DBus Respose
    case noResponse
    case returnedError(String?)
    case unexpectedResponse(for: String)
    
    // MARK: - Transit encryption
    case diffieHellmanFailed(Error)
    case secretEncryptionFailed(Error)
    case secretDecryptionFailed(Error)
    
    // MARK: - unexpected
    case unexpectedError
}
