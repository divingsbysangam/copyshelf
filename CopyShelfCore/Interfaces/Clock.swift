import Foundation

/// Capture wall time; a separate name avoids confusion with Swift.Clock.
public protocol CaptureClock: Sendable {
    func now() -> Date
}
