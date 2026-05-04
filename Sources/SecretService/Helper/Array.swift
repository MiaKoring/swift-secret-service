import DBUS

extension Array where Element == DBusValue {
    /// Tries to convert [DBusValue] to [UInt8]
    /// Returns nil if the array contains something not a byte
    var asByteArray: [UInt8]? {
        var result = [UInt8]()
        
        for element in self {
            guard let byte = element.byte else {
                print("found unexpected type")
                return nil
            }
            
            result.append(byte)
        }
        
        return result
    }
}

extension Array where Element == UInt8 {
    /// Converts to [DBusValue.byte]
    var asDBusByteArray: [DBusValue] {
        self.map { byte in
                .byte(byte)
        }
    }
}

extension Array {
    subscript(_ index: Int, default: Element?) -> Element? {
        if count > index && index >= 0 {
            return self[index]
        }
        return `default`
    }
}

