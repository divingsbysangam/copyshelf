import Foundation

/// The caller must provide a consent decision; the app supplies false until CS-13.
@MainActor
public final class CaptureSession {
    private let settings: AppSettings
    private let polling: CapturePolling
    private let isAuthorized: @MainActor () -> Bool
    public private(set) var isStopping = false

    public init(settings: AppSettings, polling: CapturePolling,
                isAuthorized: @escaping @MainActor () -> Bool) {
        self.settings = settings
        self.polling = polling
        self.isAuthorized = isAuthorized
    }

    public func resume() {
        guard isAuthorized(), !isStopping else { return }
        settings.capturePaused = false
        polling.start()
    }

    public func pause() async {
        guard !isStopping else { return }
        isStopping = true
        settings.capturePaused = true
        await polling.stopAndWait()
        isStopping = false
    }
}
