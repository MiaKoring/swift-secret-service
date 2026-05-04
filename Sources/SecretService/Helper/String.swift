extension String {
    var asDBusPath: String {
        "/" + self.replacingOccurrences(of: ".", with: "/")
    }
}
