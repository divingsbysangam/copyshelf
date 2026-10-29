import Foundation

/// Captures a target only on a hidden-to-visible transition and owns one monitor pair.
@MainActor public final class PanelLifecycle {
    public private(set) var isVisible = false
    public private(set) var targetPID: Int32?
    private let startMonitors: @MainActor () -> Void
    private let stopMonitors: @MainActor () -> Void

    public init(startMonitors: @escaping @MainActor () -> Void, stopMonitors: @escaping @MainActor () -> Void) {
        self.startMonitors = startMonitors
        self.stopMonitors = stopMonitors
    }
    @discardableResult public func show(targetPID: Int32?) -> Bool {
        guard !isVisible else { return false }
        if let targetPID { self.targetPID = targetPID }
        isVisible = true
        startMonitors()
        return true
    }
    @discardableResult public func hide() -> Bool {
        guard isVisible else { return false }
        isVisible = false
        stopMonitors()
        return true
    }
}
