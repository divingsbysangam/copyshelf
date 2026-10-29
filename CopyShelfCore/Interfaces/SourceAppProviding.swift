@MainActor
public protocol SourceAppProviding: Sendable {
    func frontmostSource() -> SourceApp
}
