import DBUS

extension Array where Element == DBusValue {
    /// Tries to convert [DBusValue] to [UInt8]
    /// Returns nil if the array contains something not a byte
    public var asByteArray: [UInt8]? {
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
    
    /// Tries to convert [DBusValue] to [String] as objectPaths
    /// Returns nil if the array contains something not a byte
    public var asObjectPathArray: [String]? {
        var result = [String]()
        
        for element in self {
            guard let byte = element.objectPath else {
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

extension Array where Element == String {
    /// Converts to [DBusValue.objectPath]
    var asDBusObjectPathArray: [DBusValue] {
        self.map { path in
            .objectPath(path)
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

