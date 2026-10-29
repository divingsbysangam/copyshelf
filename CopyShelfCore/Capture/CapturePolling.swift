import AppKit
import Foundation

/// Kept separate from the shell until the CS-13 consent gate is satisfied.
@MainActor
public final class CapturePolling {
    private let capture: TextCapture
    private let onError: @MainActor (Error) -> Void
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    public init(capture: TextCapture, onError: @escaping @MainActor (Error) -> Void) {
        self.capture = capture
        self.onError = onError
    }

    public func start() {
        guard timer == nil else { return }
        capture.start()
        scheduleTimer()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        }
    }

    public func stopAndWait() async {
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        await capture.stopAndWait()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TextCapture.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func wake() { scheduleTimer(); tick() }
    private func tick() {
        Task { @MainActor in
            do { try await capture.poll() } catch { onError(error) }
        }
    }
}
