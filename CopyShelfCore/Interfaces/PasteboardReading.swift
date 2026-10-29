@MainActor
public protocol PasteboardReading: Sendable {
    var changeCount: Int { get }
    func readText() throws -> String?
    func availableTypes() -> Set<String>
}

public extension PasteboardReading {
    func availableTypes() -> Set<String> { [] }
}
