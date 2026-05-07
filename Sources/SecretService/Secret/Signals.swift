import DBUS

public enum Signals {
    public enum Prompt {
        case completed
    }
}

extension SecretService {
    public func awaitPromptCompleted() async throws(SecSError) -> (
        dismissed: Bool,
        result: DBusValue
    )? {
        let signalStream = await dbusClientConnection.subscribeToSignal(
            interface: SecS.Iface.prompt,
            member: "Completed"
        )
        
        for await message in signalStream {
            guard
                message.messageType == .signal,
                message.body.count >= 2,
                let dismissed = message.body[0].boolean
            else {
                throw .unexpectedResponse(for: "Signal Prompt.Completed")
            }
            
            return (dismissed: dismissed, result: message.body[1])
        }
        
        return nil
    }
}
