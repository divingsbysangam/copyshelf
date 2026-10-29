import CopyShelfCore
import Foundation
import Testing

@MainActor private final class FakePasteEnvironment: PasteEnvironment {
    var authorized = true
    var trusted = true
    var exists = true
    var focused = true
    var activation = true
    var failEvent = false
    var sends = 0
    var closes = 0
    var waitActivation = false
    var continuation: CheckedContinuation<Bool, Never>?
    func isAuthorized() -> Bool { authorized }
    func isTrusted() -> Bool { trusted }
    func targetExists(_ target: PasteTarget) -> Bool { exists }
    func closePanel() { closes += 1 }
    func activate(_ target: PasteTarget) async -> Bool {
        if waitActivation { return await withCheckedContinuation { continuation = $0 } }
        return activation
    }
    func focusMatches(_ target: PasteTarget) -> Bool { focused }
    func sendPasteShortcut(to target: PasteTarget) throws {
        if failEvent { throw ClipboardWriteError.failed }
        sends += 1
    }
}

@Suite @MainActor struct PasteCoordinatorTests {
    private func setup() -> (PasteCoordinator, FakePasteEnvironment, HistoryItem, PasteTarget) {
        let board = FakePasteboard()
        let repo = InMemoryHistoryRepository()
        let capture = TextCapture(pasteboard: board, sources: FakeSourceAppProvider(), clock: FakeClock(), repository: repo)
        let copy = CopyCoordinator(writer: board, capture: capture, isAuthorized: { true })
        let env = FakePasteEnvironment()
        return (PasteCoordinator(environment: env, copy: copy), env,
                HistoryItem(id: UUID(), createdAt: Date(), text: "synthetic", source: SourceApp()),
                PasteTarget(pid: 123, launchDate: Date(), focusToken: UUID()))
    }
    @Test func denialMissingAndFailedEventNeverSend() async {
        let (paste, env, item, target) = setup()
        await paste.paste(nil, to: target)
        #expect(paste.outcome == .noSelection)
        env.authorized = false
        await paste.paste(item, to: target)
        #expect(paste.outcome == .consentRequired)
        env.authorized = true; env.trusted = false
        await paste.paste(item, to: target)
        #expect(paste.outcome == .accessibilityRequired)
        env.trusted = true; env.exists = false
        await paste.paste(item, to: target)
        #expect(paste.outcome == .targetUnavailable)
        env.exists = true; env.failEvent = true
        await paste.paste(item, to: target)
        #expect(paste.outcome == .eventFailed && env.sends == 0)
    }
    @Test func changedFocusOrRevokedPermissionDoesNotSend() async {
        for mode in 0..<3 {
            let (paste, env, item, target) = setup()
            env.waitActivation = true
            let first = Task { await paste.paste(item, to: target) }
            while env.continuation == nil { await Task.yield() }
            if mode == 0 { env.focused = false }
            else if mode == 1 { env.trusted = false }
            else { env.exists = false }
            env.continuation?.resume(returning: true)
            await first.value
            let expected: PasteOutcome = mode == 0 ? .focusChanged : (mode == 1 ? .permissionRevoked : .targetLost)
            #expect(paste.outcome == expected && env.sends == 0)
        }
    }
    @Test func cancelAndRepeatedRequestsDoNotSend() async {
        let (paste, env, item, target) = setup()
        env.waitActivation = true
        let first = Task { await paste.paste(item, to: target) }
        while env.continuation == nil { await Task.yield() }
        await paste.paste(item, to: target)
        #expect(paste.outcome == .busy)
        paste.cancel()
        env.continuation?.resume(returning: true)
        await first.value
        #expect(paste.outcome == .cancelled && env.sends == 0 && env.closes == 1)
    }
    @Test func activationFailureReportsCopiedWithoutPosting() async {
        let (paste, env, item, target) = setup()
        env.activation = false
        await paste.paste(item, to: target)
        #expect(paste.outcome == .activationFailed && env.sends == 0)
    }
    @Test func copyFailureDoesNotClaimCopiedOrPost() async {
        let board = FakePasteboard()
        let capture = TextCapture(pasteboard: board, sources: FakeSourceAppProvider(), clock: FakeClock(), repository: InMemoryHistoryRepository())
        let copy = CopyCoordinator(writer: BrokenPasteWriter(), capture: capture, isAuthorized: { true })
        let env = FakePasteEnvironment()
        let paste = PasteCoordinator(environment: env, copy: copy)
        let item = HistoryItem(id: UUID(), createdAt: Date(), text: "synthetic", source: SourceApp())
        await paste.paste(item, to: PasteTarget(pid: 123, launchDate: Date(), focusToken: UUID()))
        #expect(paste.outcome == .copyFailed && env.sends == 0 && env.closes == 0)
    }
    @Test func successPostsOnce() async {
        let (paste, env, item, target) = setup()
        await paste.paste(item, to: target)
        #expect(paste.outcome == .shortcutSent && env.sends == 1)
    }

}

@MainActor private struct BrokenPasteWriter: PasteboardWriting {
    func writeText(_ text: String) throws -> Int { throw ClipboardWriteError.failed }
}
