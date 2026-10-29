@MainActor
public protocol PasteboardWriting: Sendable {
    /// Returns the resulting change count only after a successful write.
    /// Capture uses that count to suppress its own restore; failures throw.
    @discardableResult
    func writeText(_ text: String) throws -> Int
}
