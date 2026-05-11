import SecretService

extension Error {
    var asSecSError: SecSError {
        if let secSError = self as? SecSError {
            return secSError
        }
        
        return .unexpectedError(self)
    }
}
