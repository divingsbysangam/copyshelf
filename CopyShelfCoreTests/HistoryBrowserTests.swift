import CopyShelfCore
import Foundation
import Testing

@Suite @MainActor
struct HistoryBrowserTests {
    @Test func searchIdentityAndClear() async throws {
        let repo = InMemoryHistoryRepository()
        let first = try await repo.insert(CapturedText(text: "Café\nSYNTHETIC", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: 1)))
        let second = try await repo.insert(CapturedText(text: "fixture", source: SourceApp(bundleID: "fixture.app"), capturedAt: Date(timeIntervalSince1970: 2)))
        let browser = HistoryBrowser(repository: repo)
        await browser.refresh()
        #expect(browser.items.map(\.id) == [second.id, first.id])
        browser.query = "café"
        #expect(browser.visibleItems.map(\.id) == [first.id])
        browser.query = "not present"
        #expect(browser.visibleItems.isEmpty)
        browser.query = ""
        try await repo.delete(id: second.id)
        await browser.refresh()
        #expect(browser.items.map(\.id) == [first.id])
        await browser.clearAll()
        #expect(browser.items.isEmpty && !browser.hasError)
    }
}

private enum FixtureError: Error { case unavailable }
private actor FailingHistoryRepository: HistoryRepository {
    func insert(_ capture: CapturedText) async throws -> HistoryItem { throw FixtureError.unavailable }
    func recentItems() async throws -> [HistoryItem] { throw FixtureError.unavailable }
    func setPinned(_ pinned: Bool, id: UUID) async throws { throw FixtureError.unavailable }
    func delete(id: UUID) async throws { throw FixtureError.unavailable }
    func clear(_ scope: HistoryClearScope) async throws { throw FixtureError.unavailable }
}

@MainActor struct HistoryBrowserFailureTests {
    @Test func reportsLoadAndClearErrors() async {
        let browser = HistoryBrowser(repository: FailingHistoryRepository())
        await browser.refresh()
        #expect(browser.hasError && !browser.isLoading)
        await browser.clearAll()
        #expect(browser.hasError)
    }
}

private actor DelayedHistoryRepository: HistoryRepository {
    var first: CheckedContinuation<[HistoryItem], Never>?
    var firstStarted: CheckedContinuation<Void, Never>?
    var calls = 0
    let newer = HistoryItem(id: UUID(), createdAt: Date(), text: "newer fixture", source: SourceApp())
    func waitForFirst() async {
        if calls > 0 { return }
        await withCheckedContinuation { firstStarted = $0 }
    }
    func finishFirst() { first?.resume(returning: []); first = nil }
    func recentItems() async throws -> [HistoryItem] {
        calls += 1
        if calls > 1 { return [newer] }
        firstStarted?.resume()
        firstStarted = nil
        return await withCheckedContinuation { first = $0 }
    }
    func insert(_ capture: CapturedText) async throws -> HistoryItem { newer }
    func setPinned(_ pinned: Bool, id: UUID) async throws {}
    func delete(id: UUID) async throws {}
    func clear(_ scope: HistoryClearScope) async throws {}
}

@MainActor struct HistoryBrowserRaceTests {
    @Test func lateRefreshDoesNotOverwriteNewerResults() async {
        let repo = DelayedHistoryRepository()
        let browser = HistoryBrowser(repository: repo)
        let first = Task { await browser.refresh() }
        await repo.waitForFirst()
        await browser.refresh()
        await repo.finishFirst()
        await first.value
        #expect(browser.items.map(\.text) == ["newer fixture"])
        #expect(!browser.isLoading)
    }
}
