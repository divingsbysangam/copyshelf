import CopyShelfCore

@MainActor
struct FakeSourceAppProvider: SourceAppProviding {
    var source: SourceApp = SourceApp()
    func frontmostSource() -> SourceApp { source }
}
