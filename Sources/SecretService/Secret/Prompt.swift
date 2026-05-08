import DBUS

extension SecretService {
    /// Tells SecretService to show a prompt
    /// - Parameters:
    ///   - prompt: The ObjectPath to the prompt to show
    ///   - windowID: The ID of the window to show the prompt attached to
    public func prompt(
        _ prompt: String,
        windowID: String?
    ) async throws(SecSError) {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: prompt,
            interface: SecS.Iface.prompt,
            method: "Prompt",
            body: [
                .string(windowID ?? "")
            ]
        )
        
        guard let response = try await send(request) else {
            throw .noResponse
        }
        
        guard response.messageType != .error else {
            throw .returnedError(response.body[0, nil]?.string)
        }
    }
    
    /// Dismisses a prompt
    /// - Parameters:
    ///   - prompt: The ObjectPath to the prompt to dismiss
    public func dismissPrompt(
        _ prompt: String
    ) async throws(SecSError) {        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: prompt,
            interface: SecS.Iface.prompt,
            method: "Dismiss"
        )
        
        guard let response = try await send(request) else {
            throw .noResponse
        }
        
        guard response.messageType != .error else {
            throw .returnedError(response.body[0, nil]?.string)
        }
    }
}
