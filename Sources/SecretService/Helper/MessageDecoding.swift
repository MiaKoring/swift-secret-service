import DBUS
import CryptoSwift

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
    
    func decodeGetSecrets(with symmetricKey: [UInt8]) throws(SecSError) -> [String: Secret] {
        if
            case .methodReturn = messageType,
            body.count >= 1,
            let secrets = body[0].secretsDictionary
        {
            var result = [String: Secret]()
            
            for (key, secret) in secrets {
                let decrypted = try AES.decryptAES128PKCS7(
                    encryptedData: secret.value,
                    iv: secret.parameters,
                    key: symmetricKey
                )
                result[key] = Secret(value: decrypted, contentType: secret.contentType)
            }
            
            return result
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "GetSecrets")
        }
    }
    
    func decodeSearchItems() throws(SecSError) -> [String] {
        if
            case .methodReturn = self.messageType,
            body.count >= 1,
            let items = body[0].array?.asObjectPathArray
        {
            return items
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "SearchItems")
        }
    }
    
    func decodeDeleteItem() throws(SecSError) -> String? {
        if
            case .methodReturn = self.messageType,
            body.count >= 1,
            let prompt = body[0].objectPath
        {
            return prompt != "/" ? prompt: nil
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "Items.Delete")
        }
    }
    
    func decodeGetSecret(with symmetricKey: [UInt8]) throws(SecSError) -> Secret {
        if
            case .methodReturn = messageType,
            body.count >= 1,
            let secret = body[0].secret
        {
            var result = [String: Secret]()
            
            let decrypted = try AES.decryptAES128PKCS7(
                encryptedData: secret.value,
                iv: secret.parameters,
                key: symmetricKey
            )
            
            return Secret(value: decrypted, contentType: secret.contentType)
        } else if case .error = self.messageType {
            throw .returnedError(body[0, nil]?.string)
        } else {
            throw .unexpectedResponse(for: "GetSecret")
        }
    }
}
