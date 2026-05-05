import DBUS
import CryptoSwift

extension SecretService {
    /// Delete a collection
    /// - Parameters:
    ///   - collection: The objectPath of the collection
    /// - Returns:
    ///   - ObjectPath to the Prompt item
    ///
    /// org.freedesktop.Secret.Collection.Delete
    public func deleteCollection(
        _ collection: String
    ) async throws(SecSError) -> String? {
        return ""
    }
    
    /// Search for items with certain attributes in the collection
    /// - Parameters:
    ///   - attributes: Attributes the item must have
    ///   - collection: The collection to search in
    /// - Returns:
    ///   - Array of ObjectPaths to the items matching the filter
    ///
    /// org.freedesktop.Secret.Collection.SearchItems
    public func searchItems(
        for attributes: [String: String],
        in collection: String
    ) async throws(SecSError) -> [String] {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: collection,
            interface: SecS.Iface.collection,
            method: "SearchItems",
            body: [
                .dictionary(attributes.asStringToString)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeSearchItems()
    }
    
    /// Creates a new item
    /// - Parameters:
    ///   - secret: The secret to store on the item
    ///   - collection: The collection to store the item in
    ///   - properties: The properties the item should have, such as label or attributes
    /// - Returns:
    ///   - ObjectPath to item
    ///   - Prompt (only needs to be invoked when item is nil)
    ///
    /// org.freedesktop.Secret.Collection.CreateItem
    public func createItem(
        secret: Secret,
        collection: String,
        properties: [String: DBusValue]
    ) async throws(SecSError) -> (item: String?, prompt: String?) {
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
            path: collection,
            interface: SecS.Iface.collection,
            method: "CreateItem",
            body: [
                .dictionary(properties.asStringToVariant),
                secret,
                .boolean(true)
            ]
        )
        
        guard let response = try await send(request) else { throw .noResponse }
        
        return try response.decodeCreateItem()
    }
}
