import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CopyShelfCore
import CoreGraphics

/// Keeps only an accessibility element reference, never the element's contents.
@MainActor final class SystemPasteEnvironment: PasteEnvironment {
    private let authorized: @MainActor () -> Bool
    private let close: @MainActor () -> Void
    private var savedElement: AXUIElement?
    private var savedToken: UUID?
    init(authorized: @escaping @MainActor () -> Bool, close: @escaping @MainActor () -> Void) {
        self.authorized = authorized; self.close = close
    }

    func snapshot(_ app: NSRunningApplication) -> PasteTarget? {
        savedElement = nil; savedToken = nil
        guard isAuthorized(), isTrusted(), !app.isTerminated, let date = app.launchDate else { return nil }
        var value: CFTypeRef?
        let root = AXUIElementCreateApplication(app.processIdentifier)
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        savedElement = (value as! AXUIElement)
        let token = UUID(); savedToken = token
        return PasteTarget(pid: app.processIdentifier, launchDate: date, focusToken: token)
    }

    func isAuthorized() -> Bool { authorized() }
    func isTrusted() -> Bool { AXIsProcessTrusted() }
    func targetExists(_ target: PasteTarget) -> Bool {
        guard target.focusToken == savedToken, let launchDate = target.launchDate,
              let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else { return false }
        return app.launchDate == launchDate
    }
    func closePanel() { close() }
    func activate(_ target: PasteTarget) async -> Bool {
        guard targetExists(target), let app = NSRunningApplication(processIdentifier: target.pid) else { return false }
        // A nonactivating panel commonly leaves the original app frontmost.
        // Do not require a redundant activation request to succeed in that case.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid { return true }
        let watch = ActivationWatch(targetPID: target.pid)
        let center = NSWorkspace.shared.notificationCenter
        let observer = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { watch.observe(pid) }
        }
        defer { center.removeObserver(observer) }
        guard app.activate() else { return false }
        for _ in 0..<20 {
            guard !watch.interrupted, targetExists(target) else { return false }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid { return true }
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return false }
        }
        return false
    }
    func focusMatches(_ target: PasteTarget) -> Bool {
        guard targetExists(target), NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else { return false }
        var value: CFTypeRef?
        let root = AXUIElementCreateApplication(target.pid)
        guard let savedElement else { return false }
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        return CFEqual(savedElement, value)
    }

    func sendPasteShortcut(to target: PasteTarget) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            throw ClipboardWriteError.failed
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.postToPid(target.pid); up.postToPid(target.pid)
    }
}

@MainActor private final class ActivationWatch {
    private let targetPID: pid_t
    private(set) var interrupted = false
    init(targetPID: pid_t) { self.targetPID = targetPID }
    func observe(_ pid: pid_t?) {
        if pid != targetPID { interrupted = true }
    }
}
