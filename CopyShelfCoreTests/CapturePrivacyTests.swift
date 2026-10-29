import CopyShelfCore
import Foundation
import Testing

@Suite @MainActor
struct CapturePrivacyTests {
    @Test func pausedExcludedAndMarkedNeverReadText() async throws {
        let board = FakePasteboard()
        let source = PrivacySource()
        let repo = InMemoryHistoryRepository()
        var paused = true
        var excluded: Set<String> = []
        let capture = TextCapture(pasteboard: board, sources: source, clock: FakeClock(), repository: repo,
                                  isPaused: { paused }, excludedBundleIDs: { excluded })
        capture.start()
        try board.writeText("paused fixture")
        try await capture.poll()
        #expect(board.readCount == 0)
        paused = false
        try await capture.poll() // Resume establishes a baseline; paused content is not imported.
        #expect(board.readCount == 0)
        excluded = ["fixture.excluded"]
        try board.writeText("excluded fixture")
        try await capture.poll()
        #expect(board.readCount == 0)
        excluded = []
        for type in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "com.agilebits.onepassword"] {
            board.types = [type]
            try board.writeText("marked fixture")
            try await capture.poll()
        }
        #expect(board.readCount == 0)
        board.types = []
        source.source = SourceApp(bundleID: "com.sangam.copyshelf")
        try board.writeText("own fixture")
        try await capture.poll()
        #expect(board.readCount == 0)
        #expect(try await repo.recentItems().isEmpty)
        source.source = SourceApp(bundleID: "fixture.allowed")
        try board.writeText("allowed fixture")
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
    }

    @Test func exclusionsPersist() {
        let name = "CopyShelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        AppSettings(defaults: defaults).excludedBundleIDs = ["fixture.one", "fixture.two"]
        #expect(AppSettings(defaults: defaults).excludedBundleIDs == ["fixture.one", "fixture.two"])
    }
}

@MainActor private final class PrivacySource: SourceAppProviding {
    var source = SourceApp(bundleID: "fixture.excluded")
    func frontmostSource() -> SourceApp { source }
}

private actor BlockingRepository: HistoryRepository {
    private var stored: [HistoryItem] = []
    private var insertContinuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var started = false

    func waitUntilInsertStarts() async {
        if started { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }
    func releaseInsert() { insertContinuation?.resume(); insertContinuation = nil }
    func insert(_ capture: CapturedText) async throws -> HistoryItem {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { insertContinuation = $0 }
        let item = HistoryItem(id: UUID(), createdAt: capture.capturedAt, text: capture.text, source: capture.source)
        stored.append(item)
        return item
    }
    func recentItems() async throws -> [HistoryItem] { stored }
    func setPinned(_ pinned: Bool, id: UUID) async throws {}
    func delete(id: UUID) async throws {}
    func clear(_ scope: HistoryClearScope) async throws { stored.removeAll() }
}

@MainActor
struct CaptureDrainTests {
    @Test func pauseWaitsForDispatchedSave() async throws {
        let board = FakePasteboard()
        let repo = BlockingRepository()
        let capture = TextCapture(pasteboard: board, sources: PrivacySource(), clock: FakeClock(), repository: repo)
        capture.start()
        try board.writeText("synthetic pending save")
        let poll = Task { try await capture.poll() }
        await repo.waitUntilInsertStarts()
        var pauseCompleted = false
        let pause = Task { await capture.stopAndWait(); pauseCompleted = true }
        await Task.yield()
        #expect(!pauseCompleted)
        await repo.releaseInsert()
        try await poll.value
        await pause.value
        #expect(pauseCompleted)
        try board.writeText("synthetic after pause")
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
    }
}

@MainActor struct CaptureSessionTests {
    @Test func consentAndPauseAreEnforced() async throws {
        let name = "CopyShelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: PrivacySource(), clock: FakeClock(), repository: repo,
                                  isPaused: { settings.capturePaused })
        let polling = CapturePolling(capture: capture) { _ in Issue.record("Unexpected poll failure") }
        var authorized = false
        let session = CaptureSession(settings: settings, polling: polling, isAuthorized: { authorized })
        session.resume()
        #expect(settings.capturePaused)
        authorized = true
        session.resume()
        #expect(!settings.capturePaused)
        try board.writeText("synthetic session")
        try await Task.sleep(for: .milliseconds(600))
        #expect(try await repo.recentItems().count == 1)
        await session.pause()
        #expect(settings.capturePaused)
        try board.writeText("synthetic paused")
        try await Task.sleep(for: .milliseconds(400))
        #expect(try await repo.recentItems().count == 1)
        session.resume()
        try await Task.sleep(for: .milliseconds(400))
        #expect(try await repo.recentItems().count == 1)
        await session.pause()
    }
}
