import DBUS

extension DBusMessage {
    func decodeOpenSession() throws(SecretServiceError) -> (publicKey: [UInt8], sessionPath: String) {
        if
            case .methodReturn = self.messageType,
            body.count >= 2,
            let bobPublic = body[0].array?.asByteArray,
            let sessionPath = body[1].objectPath
        {
            return (publicKey: bobPublic, sessionPath: sessionPath)
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "OpenSession")
        }
    }
    
    func decodeReadAlias() throws(SecSError) -> String? {
        if
            case .methodReturn = self.messageType,
            body.count >= 1,
            let objectPath = body[0].objectPath
        {
            return objectPath != "/" ? objectPath: nil
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "ReadAlias")
        }
    }
    
    func decodeCreateItem() throws(SecSError) -> (item: String?, prompt: String?) {
        if
            case .methodReturn = self.messageType,
            body.count >= 2,
            let item = body[0].objectPath,
            let prompt = body[1].objectPath
        {
            return (
                item: item != "/" ? item: nil,
                prompt: prompt != "/" ? prompt: nil
            )
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "CreateItem")
        }
    }
}
