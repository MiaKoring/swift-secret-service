import DBUS

extension DBusValue {
    static func secret(
        session: String,
        parameters: [UInt8],
        value: [UInt8],
        contentType: String
    ) -> DBusValue {
        .structure([
            .objectPath(session),
            .array(parameters.asDBusByteArray),
            .array(value.asDBusByteArray),
            .string(contentType)
        ])
    }
}
