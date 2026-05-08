import DBUS

extension SecretService {
    /// Read a property of an object.
    /// - Parameters:
    ///   - name: The name of the property (e.g. "Collections").
    ///   - interface: The interface the property is declared on (e.g. "org.freedesktop.Secret.Service").
    ///   - object: The ObjectPath of the instance. If nil, defaults to the service root "/org/freedesktop/secrets".
    public func readProperty(
        _ name: String,
        interface: String,
        object: String? = nil
    ) async throws(SecSError) -> DBusValue {
        let request = DBusRequest.createMethodCall(
            destination: SecS.service,
            path: object ?? SecS.service.asDBusPath,
            interface: "org.freedesktop.DBus.Properties",
            method: "Get",
            body: [
                .string(interface),
                .string(name)
            ]
        )
        
        guard let response = try await send(request) else {
            throw .noResponse
        }
        
        if response.messageType == .error {
            throw .returnedError(response.body[0, nil]?.string)
        }
        
        guard let property = response.body[0, nil] else {
            throw .unexpectedResponse(for: "Get Property \(name) on \(interface)")
        }
        
        return property
    }
}
