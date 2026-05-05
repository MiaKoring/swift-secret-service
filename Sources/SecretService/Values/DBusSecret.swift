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
    
    var secretsDictionary: [String: DBusSecret]? {
        var result = [String: DBusSecret]()
        switch self {
            case .dictionary(let dictionary):
                for (key, value) in dictionary {
                    // return nil if expected pattern isn't matched
                    guard let key = key.objectPath else { return nil }
                    guard
                        let value = value.structure,
                        let secret = DBusSecret(structure: value)
                    else { return nil }
                    result[key] = secret
                }
            default:
                return nil
        }
        return result
    }
    
    var secret: DBusSecret? {
        switch self {
            case .structure(let array):
                return DBusSecret(structure: array)
            default: return nil
        }
    }
}

/// The unencrypted representation of a Secret.
/// ``SecretService`` automatically manages encryption in transit.
public struct Secret: Sendable {
    /// The unencrypted Data of the secret as byte array
    let value: [UInt8]
    /// The content type of the stored data
    /// e.g. `text/plain; charset=utf8`
    let contentType: String
    
    init(value: [UInt8], contentType: String = "text/plain; charset=utf8") {
        self.value = value
        self.contentType = contentType
    }
}

struct DBusSecret: Sendable {
    let session: String
    let parameters: [UInt8]
    let value: [UInt8]
    let contentType: String
    
    init?(structure: [DBusValue]) {
        guard
            structure.count >= 4,
            let session = structure[0].objectPath,
            let parameters = structure[1].array?.asByteArray,
            let value = structure[2].array?.asByteArray,
            let contentType = structure[3].string
        else { return nil }
        
        self.session = session
        self.parameters = parameters
        self.value = value
        self.contentType = contentType
    }
}
