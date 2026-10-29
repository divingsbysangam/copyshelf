import Foundation
import Observation

public enum CopyOutcome: Equatable, Sendable {
    case copied
    case noSelection
    case consentRequired
    case failed
}

@MainActor @Observable
public final class CopyCoordinator {
    private let writer: any PasteboardWriting
    private let capture: TextCapture
    private let isAuthorized: @MainActor () -> Bool
    public private(set) var outcome: CopyOutcome?

    public init(writer: any PasteboardWriting, capture: TextCapture,
                isAuthorized: @escaping @MainActor () -> Bool) {
        self.writer = writer
        self.capture = capture
        self.isAuthorized = isAuthorized
    }

    public func clearOutcome() { outcome = nil }

    public func copy(_ item: HistoryItem?) {
        guard let item else { outcome = .noSelection; return }
        guard isAuthorized() else { outcome = .consentRequired; return }
        do {
            let count = try writer.writeText(item.text)
            capture.suppressOwnWrite(changeCount: count)
            outcome = .copied
        } catch { outcome = .failed }
    }

}
