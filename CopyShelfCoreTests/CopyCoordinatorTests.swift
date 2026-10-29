import CopyShelfCore
import Foundation
import Testing

@Suite @MainActor struct CopyCoordinatorTests {
    @Test func copyPreservesExactTextAndSuppressesLoop() async throws {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: FakeSourceAppProvider(), clock: FakeClock(), repository: repo)
        capture.start()
        let item = HistoryItem(id: UUID(), createdAt: Date(), text: "  café\n👋\t", source: SourceApp())
        let copy = CopyCoordinator(writer: board, capture: capture, isAuthorized: { true })
        copy.copy(item)
        #expect(copy.outcome == .copied)
        let written = try board.readText()
        #expect(Array(try #require(written).utf8) == Array(item.text.utf8))
        try await capture.poll()
        #expect(try await repo.recentItems().isEmpty)
        copy.copy(nil)
        #expect(copy.outcome == .noSelection)
        await capture.stopAndWait()
    }

    @Test func consentAndFailureReportTruthfully() {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: FakeSourceAppProvider(), clock: FakeClock(), repository: repo)
        let item = HistoryItem(id: UUID(), createdAt: Date(), text: "synthetic", source: SourceApp())
        let denied = CopyCoordinator(writer: board, capture: capture, isAuthorized: { false })
        denied.copy(item)
        #expect(denied.outcome == .consentRequired && board.changeCount == 0)
        let failed = CopyCoordinator(writer: FailingWriter(), capture: capture, isAuthorized: { true })
        failed.copy(item)
        #expect(failed.outcome == .failed)
    }


}

@MainActor private struct FailingWriter: PasteboardWriting {
    func writeText(_ text: String) throws -> Int { throw ClipboardWriteError.failed }
}
