import CopyShelfCore
import Foundation
import Observation

/// Owns the single repository and dormant capture components for the app lifetime.
/// Capture requires a deliberate consent action and always starts paused.
@MainActor @Observable
final class CaptureRuntime {
    private(set) var unavailable = true
    private(set) var captureError: String?
    private(set) var repository: (any HistoryRepository)?
    private(set) var history: HistoryBrowser?
    private(set) var copy: CopyCoordinator?
    private var session: CaptureSession?
    private let settings: AppSettings
    var captureAuthorized: Bool { settings.captureConsentGranted }

    init(settings: AppSettings, inMemory: Bool = false) {
        self.settings = settings
        // A prior consent never resumes capture automatically on launch.
        settings.capturePaused = true
        let policy = RetentionPolicy(unpinnedLimit: settings.unpinnedHistoryLimit)
        if inMemory {
            do {
                let repository = try HistoryStore.inMemory(policy: policy)
                let board = InMemoryPasteboard()
                configure(repository: repository, reader: board, writer: board, sources: InMemorySource())
            } catch { unavailable = true }
        } else {
            Task { @MainActor in
                do {
                    let location = StoreLocation()
                    let prepared = try await RichStorePreparation.open(location: location)
                    let repository = TextOnlyV2Repository(container: prepared.container, policy: policy)
                    configure(repository: repository, reader: SystemPasteboardReader(),
                              writer: SystemPasteboardWriter(), sources: SystemSourceAppProvider())
                } catch { unavailable = true }
            }
        }
    }

    private func configure(repository: any HistoryRepository,
                           reader: any PasteboardReading, writer: any PasteboardWriting,
                           sources: any SourceAppProviding) {
            let settings = self.settings
            let history = HistoryBrowser(repository: repository)
            let capture = TextCapture(pasteboard: reader, sources: sources,
                                      clock: SystemCaptureClock(), repository: repository,
                                      isPaused: { settings.capturePaused },
                                      excludedBundleIDs: { Set(settings.excludedBundleIDs) },
                                      onCaptured: { [weak self, weak history] in
                                          self?.captureError = nil
                                          guard let history else { return }
                                          Task { await history.refresh() }
                                      })
            self.repository = repository
            self.history = history
            self.copy = CopyCoordinator(writer: writer, capture: capture, isAuthorized: { settings.captureConsentGranted })
            let polling = CapturePolling(capture: capture) { [weak self] _ in
                self?.captureError = "An item could not be saved. Check storage and try again."
            }
            self.session = CaptureSession(settings: settings, polling: polling, isAuthorized: { settings.captureConsentGranted })
            unavailable = false
    }

    func authorizeAndResume() {
        guard !unavailable else { return }
        settings.captureConsentGranted = true
        session?.resume()
    }
    func revoke() async {
        settings.captureConsentGranted = false
        await session?.pause()
    }
    func resume() { session?.resume() }
    func pause() async { await session?.pause() }
}

@MainActor private final class InMemoryPasteboard: PasteboardReading, PasteboardWriting {
    private(set) var changeCount = 0
    private var text: String?
    func readText() throws -> String? { text }
    func writeText(_ text: String) throws -> Int { self.text = text; changeCount += 1; return changeCount }
}
@MainActor private struct InMemorySource: SourceAppProviding {
    func frontmostSource() -> SourceApp { SourceApp() }
}
