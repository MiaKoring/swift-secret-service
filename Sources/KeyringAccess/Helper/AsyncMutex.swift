actor AsyncMutex<T: Sendable> {
    private var value: T
    
    init(value: T) { self.value = value }
    
    // Provide sync methods to touch the data
    private func updateValue(_ newValue: T) {
        self.value = newValue
    }
    
    /// Sets the the returned value of block as new value and returns it.
    func withLock(
        _ block: @Sendable @escaping (T) async throws -> T
    ) async rethrows -> T {
        // Runs one at a time because it's an actor method
        let newValue = try await block(value)
        self.value = newValue
        return value
    }
}
