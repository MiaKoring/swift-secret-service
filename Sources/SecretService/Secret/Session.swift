import DBUS

// Method implementation complete
extension SecretService {
    func disconnect() async throws(SecSError) {
        let (session, _) = try getSession()
        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: session,
            interface: SecS.Iface.session,
            method: "Close"
        )
        
        guard let response = try await send(request) else {
            throw .noResponse
        }
        
        guard response.messageType != .error else {
            throw .returnedError(response.body[0, nil]?.string)
        }
    }
}
