import DBUS

extension Dictionary where Key == String, Value == DBusValue {
    var asStringToVariant: [DBusValue: DBusValue] {
        var new = [DBusValue: DBusValue]()
        
        for (key, value) in self {
            new[.string(key)] = .variant(.init(value))
        }
        
        return new
    }
}

extension Dictionary where Key == String, Value == String {
    var asStringToString: [DBusValue: DBusValue] {
        var new = [DBusValue: DBusValue]()
        
        for (key, value) in self {
            new[.string(key)] = .string(value)
        }
        
        return new
    }
}
