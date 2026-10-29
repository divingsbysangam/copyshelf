import CopyShelfCore
import Foundation
import Testing

@Suite @MainActor
struct HistoryFilterTests {
    @Test func filtersPinsSourcesAndSelection() async throws {
        let repo = try HistoryStore.inMemory(policy: RetentionPolicy(unpinnedLimit: 2))
        let old = try await repo.insert(CapturedText(text: "old", source: SourceApp(bundleID: "fixture.a", name: "Editor"), capturedAt: Date(timeIntervalSince1970: 1)))
        let middle = try await repo.insert(CapturedText(text: "middle", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: 2)))
        let browser = HistoryBrowser(repository: repo)
        await browser.refresh()
        browser.filter = .pinned
        #expect(browser.visibleItems.isEmpty)
        browser.filter = .source("missing.app")
        #expect(browser.visibleItems.isEmpty)
        browser.filter = .all
        #expect(browser.sources.map(\.name).contains("Unknown"))
        browser.selectNext(1)
        #expect(browser.selectedID == middle.id)
        browser.selectNext(-1)
        #expect(browser.selectedID == middle.id)
        browser.selectNext(1)
        #expect(browser.selectedID == old.id)
        browser.selectNext(1)
        #expect(browser.selectedID == old.id)
        await browser.setPinned(true, id: old.id)
        #expect(browser.selectedItem?.isPinned == true)
        _ = try await repo.insert(CapturedText(text: "new", source: SourceApp(bundleID: "fixture.b", name: "Other"), capturedAt: Date(timeIntervalSince1970: 3)))
        _ = try await repo.insert(CapturedText(text: "newest", source: SourceApp(bundleID: "fixture.b", name: "Other"), capturedAt: Date(timeIntervalSince1970: 4)))
        await browser.refresh()
        #expect(browser.selectedID == old.id)
        #expect(!browser.items.contains { $0.id == middle.id })
        browser.filter = .pinned
        #expect(browser.visibleItems.map(\.id) == [old.id])
        await browser.setPinned(false, id: old.id)
        #expect(browser.visibleItems.isEmpty && browser.selectedID == nil)
        browser.filter = .source("fixture.b")
        #expect(browser.visibleItems.count == 2)
        browser.selectNext(1)
        let selected = browser.selectedID!
        try await repo.delete(id: selected)
        await browser.refresh()
        #expect(browser.selectedID != selected && browser.selectedID != nil)
        browser.query = "missing"
        #expect(browser.visibleItems.isEmpty && browser.selectedID == nil)
    }
}
