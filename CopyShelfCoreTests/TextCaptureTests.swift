import AppKit
import CopyShelfCore
import Foundation
import Testing

@Suite @MainActor
struct TextCaptureTests {
    @Test func captureAndDuplicates() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let source = MutableSource()
        let capture = TextCapture(pasteboard: board, sources: source, clock: FakeClock(), repository: repo)
        capture.start()
        try await capture.poll()
        #expect(try await repo.recentItems().isEmpty)
        let text = "  café\n👩🏽‍💻\t"
        try board.writeText(text)
        try await capture.poll()
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
        #expect(try await repo.recentItems().first?.text == text)
        try board.writeText(text)
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
        source.source = SourceApp(bundleID: "fixture.other", name: "Other")
        try board.writeText(text)
        try await capture.poll()
        #expect(try await repo.recentItems().count == 2)
        #expect(source.calls == 3)
    }

    @Test func fileURLsAreIgnoredEvenWithTextRepresentation() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
        capture.start()
        board.types = ["public.file-url", "public.utf8-plain-text"]
        try board.writeText("synthetic file path")
        try await capture.poll()
        #expect(board.readCount == 0)
        #expect(try await repo.recentItems().isEmpty)
        board.types = []
        try board.writeText("synthetic text")
        try await capture.poll()
        #expect(try await repo.recentItems().first?.text == "synthetic text")
    }

    @Test func boundsAndExactUnicode() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
        capture.start()
        try board.writeText("")
        try await capture.poll()
        try board.writeText(String(repeating: "x", count: TextCapture.maximumUTF8Bytes + 1))
        try await capture.poll()
        #expect(try await repo.recentItems().isEmpty)
        try board.writeText(String(repeating: "x", count: TextCapture.maximumUTF8Bytes))
        try await capture.poll()
        try board.writeText("é")
        try await capture.poll()
        try board.writeText("e\u{301}")
        try await capture.poll()
        #expect(try await repo.recentItems().count == 3)
    }

    @Test func onlySuccessfulNewCapturesNotifyHistory() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        var notifications = 0
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(),
                                  repository: repo, onCaptured: { notifications += 1 })
        capture.start()
        try board.writeText("synthetic")
        try await capture.poll()
        try board.writeText("synthetic")
        try await capture.poll()
        #expect(notifications == 1)
        await capture.stopAndWait()
    }

    @Test func consecutiveDuplicatesRemainCorrectWithClockTies() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
        capture.start()
        for text in ["one", "two", "one", "one"] {
            try board.writeText(text)
            try await capture.poll()
        }
        let items = try await repo.recentItems()
        #expect(items.map(\.text) == ["one", "two", "one"])
    }

    @Test func timerAndWakeUseFixtureProvider() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
        let polling = CapturePolling(capture: capture) { _ in Issue.record("Unexpected poll error") }
        polling.start()
        try board.writeText("timer fixture")
        try await Task.sleep(for: .milliseconds(600))
        #expect(try await repo.recentItems().count == 1)
        try board.writeText("wake fixture")
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(try await repo.recentItems().count == 2)
        await polling.stopAndWait()
    }

    @Test func persistentRestartSuppressesConsecutiveDuplicate() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let location = StoreLocation(applicationSupport: base)
        let board = FakePasteboard()
        do {
            let repo = try HistoryStore.openDisk(location: location)
            let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
            capture.start()
            try board.writeText("synthetic restart")
            try await capture.poll()
            await capture.stopAndWait()
        }
        let reopened = try HistoryStore.openDisk(location: location)
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: reopened)
        capture.start()
        try board.writeText("synthetic restart")
        try await capture.poll()
        #expect(try await reopened.recentItems().count == 1)
    }

    @Test func restartWakeAndOwnWrites() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: MutableSource(), clock: FakeClock(), repository: repo)
        try board.writeText("existing")
        capture.start()
        try await capture.poll()
        #expect(try await repo.recentItems().isEmpty)
        try board.writeText("after wake")
        try await capture.poll()
        let ownCount = try board.writeText("restore")
        capture.suppressOwnWrite(changeCount: ownCount)
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
        await capture.stopAndWait()
        try board.writeText("while stopped")
        capture.start()
        try await capture.poll()
        #expect(try await repo.recentItems().count == 1)
        try board.writeText("new")
        try await capture.poll()
        #expect(try await repo.recentItems().count == 2)
        #expect(try await repo.recentItems().allSatisfy { $0.source.bundleID == nil })
    }
}

@MainActor private final class MutableSource: SourceAppProviding {
    var source = SourceApp()
    var calls = 0
    func frontmostSource() -> SourceApp { calls += 1; return source }
}
