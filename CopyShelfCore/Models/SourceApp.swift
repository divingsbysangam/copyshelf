public struct SourceApp: Sendable, Equatable {
    public let bundleID: String?
    public let name: String?

    public init(bundleID: String? = nil, name: String? = nil) {
        self.bundleID = bundleID
        self.name = name
    }

    public var displayName: String { name ?? "Unknown" }
}
