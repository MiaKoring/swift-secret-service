@_exported import DBUS

public enum Signals {
    public enum Prompt {
        case completed
    }
}

extension SecretService {
    /// Wait for the next prompt to be completed.
    /// - Returns:
    ///   - dismissed: Whether the prompt was dismissed.
    ///   - result: The value returned by the prompt.
    ///     Either an ObjectPath or an array of ObjectPath.
    public func awaitPromptCompleted() async throws(SecSError) -> (
        dismissed: Bool,
        result: DBusValue
    )? {
        try await awaitSignal (
            "Completed",
            interface: SecS.Iface.prompt
        ) { message throws(SecSError) in
            guard
                message.messageType == .signal,
                message.body.count >= 2,
                let dismissed = message.body[0].boolean
            else { throw .unexpectedResponse(for: "Signal Prompt.Completed") }
            
            return (
                (dismissed: dismissed, result: message.body[1]),
                true
            )
        }
    }
    
    /// Wait for a signal to be called.
    /// - Parameters:
    ///   - name: The name of the signal.
    ///   - interface: The interface the signal is part of.
    ///   - block: Gets called for every signal coming in with the DBusMessage as parameter.
    ///     Should return the desired value as Optional and whether to exit.
    ///     Only returns when the second part of the tuple is `true`.
    ///     If the signal is not what you wanted, return `false`.
    ///     The block will then be called again for the next signal coming in.
    /// - Returns:
    ///   - The desired value returned by the block parameter.
    ///
    /// Visit the
    /// [Secret Service Specification](
    /// https://specifications.freedesktop.org/secret-service/latest/ref-dbus-api.html
    /// ) for available signals.
    public func awaitSignal<Return, E: Error>(
        _ name: String,
        interface: String,
        block: @escaping (DBusMessage) async throws(E) -> (Return?, Bool)
    ) async throws(E) -> Return? {
        let signalStream = await dbusClientConnection.subscribeToSignal(
            interface: interface,
            member: name
        )
        
        for await message in signalStream {
            let result = try await block(message)
            if result.1 {
                return result.0
            }
        }
        
        return nil
    }
}
