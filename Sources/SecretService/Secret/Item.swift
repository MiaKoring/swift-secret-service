import DBUS
import CryptoSwift

// Method implementation complete
extension SecretService {
    /// Deletes an item
    /// - Parameters:
    ///   - item: ObjectPath of item to delete
    /// - Returns:
    ///   - ObjectPath of prompt when authorization is required
    ///
    /// org.freedesktop.Secret.Item.Delete
    public func deleteItem(
        item: String
    ) async throws(SecSError) -> String? {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: item,
            interface: SecS.Iface.item,
            method: "Delete",
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeDeleteItem()
    }
    
    /// Sets a secret on an item
    /// - Parameters:
    ///   - item: ObjectPath of item to set the ``Secret`` on
    ///   - secret: The new ``Secret`` it should be set to
    ///
    /// org.freedesktop.Secret.Item.SetSecret
    public func setSecret(
        on item: String,
        secret: Secret
    ) async throws(SecSError) {
        let (session, symmetricKey) = try getSession()
        
        let (encryptedValue, iv) = try AES.encryptAES128PKCS7(
            data: secret.value,
            key: symmetricKey
        )
        
        let secret = DBusValue.secret(
            session: session,
            parameters: iv,
            value: encryptedValue,
            contentType: secret.contentType
        )
        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: item,
            interface: SecS.Iface.item,
            method: "SetSecret",
            body: [
                secret
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        if response.messageType == .error {
            throw .returnedError(response.body[0, nil]?.string)
        }
    }
    
    /// Gets the secret of an item
    /// - Parameters:
    ///   - item: ObjectPath of the item to get the ``Secret`` of
    /// - Returns:
    ///   - The requested ``Secret``
    ///
    /// org.freedesktop.Secret.Item.GetSecret
    public func getSecret(of item: String) async throws(SecSError) -> Secret {
        let (session, symmetricKey) = try getSession()
        
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: item,
            interface: SecS.Iface.item,
            method: "GetSecret",
            body: [
                .objectPath(session)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeGetSecret(with: symmetricKey)
    }
}
