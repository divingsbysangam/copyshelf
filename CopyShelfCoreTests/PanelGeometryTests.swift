import CopyShelfCore
import Foundation
import Testing

struct PanelGeometryTests {
    @Test func centersAndFitsVisibleBounds() {
        let visible = CGRect(x: -1000, y: 40, width: 800, height: 600)
        let normal = PanelGeometry.frame(requested: CGSize(width: 480, height: 320), visible: visible)
        #expect(visible.contains(normal))
        #expect(normal.midX == visible.midX && normal.midY == visible.midY)
        let small = CGRect(x: 0, y: 0, width: 300, height: 180)
        #expect(PanelGeometry.frame(requested: CGSize(width: 480, height: 320), visible: small) == small)
    }
}

@MainActor private final class FakeShortcutBackend: ShortcutBackend {
    var installed = 0
    var removed = 0
    var registered = 0
    var unregistered = 0
    var registrationSucceeds = true
    var rejected: ShortcutConfiguration?
    func installHandler() -> Bool { installed += 1; return true }
    func removeHandler() { removed += 1 }
    func register(_ shortcut: ShortcutConfiguration) -> Bool { registered += 1; return registrationSucceeds && shortcut != rejected }
    func unregister() { unregistered += 1 }
}

@MainActor struct ShortcutLifecycleTests {
    @Test func repeatedStartWakeAndStop() {
        let backend = FakeShortcutBackend()
        let lifecycle = ShortcutLifecycle(backend: backend)
        lifecycle.start()
        lifecycle.start()
        #expect(backend.installed == 1 && backend.registered == 1)
        lifecycle.wake()
        lifecycle.wake()
        #expect(backend.installed == 1 && backend.registered == 3 && backend.unregistered == 2)
        lifecycle.stop()
        lifecycle.stop()
        #expect(backend.removed == 1 && backend.unregistered == 3)
    }
    @Test func failedChangeRestoresPreviousRegistration() {
        let backend = FakeShortcutBackend()
        let lifecycle = ShortcutLifecycle(backend: backend)
        lifecycle.start()
        let candidate = ShortcutConfiguration(keyCode: 11, modifiers: ShortcutConfiguration.command | ShortcutConfiguration.control)
        backend.rejected = candidate
        #expect(!lifecycle.change(to: candidate))
        #expect(lifecycle.configuration == .standard && !lifecycle.unavailable)
        #expect(backend.registered == 3 && backend.unregistered == 1)
        backend.rejected = nil
        #expect(lifecycle.change(to: candidate) && lifecycle.configuration == candidate)
        lifecycle.stop()
    }
    @Test func defaultsAndPersistence() {
        let name = "CopyShelfShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(ShortcutConfiguration.load(from: defaults) == .standard)
        let saved = ShortcutConfiguration(keyCode: 11, modifiers: ShortcutConfiguration.command | ShortcutConfiguration.control)
        saved.save(to: defaults)
        #expect(ShortcutConfiguration.load(from: defaults) == saved)
        defaults.set(999, forKey: "shortcutModifiers")
        #expect(ShortcutConfiguration.load(from: defaults) == .standard)
    }
    @Test func conflictIsVisibleAndWakeRetries() {
        let backend = FakeShortcutBackend()
        backend.registrationSucceeds = false
        let lifecycle = ShortcutLifecycle(backend: backend)
        lifecycle.start()
        #expect(lifecycle.unavailable)
        backend.registrationSucceeds = true
        lifecycle.wake()
        #expect(!lifecycle.unavailable && backend.unregistered == 0)
        lifecycle.stop()
    }
}

@MainActor struct PanelLifecycleTests {
    @Test func showHideDoesNotDuplicateMonitorsOrOverwriteTarget() {
        var starts = 0
        var stops = 0
        let lifecycle = PanelLifecycle(startMonitors: { starts += 1 }, stopMonitors: { stops += 1 })
        #expect(lifecycle.show(targetPID: 42))
        #expect(!lifecycle.show(targetPID: 99))
        #expect(lifecycle.targetPID == 42 && starts == 1)
        #expect(lifecycle.hide())
        #expect(!lifecycle.hide())
        #expect(stops == 1)
        #expect(lifecycle.show(targetPID: nil))
        #expect(lifecycle.targetPID == 42 && starts == 2)
        #expect(lifecycle.hide() && stops == 2)
    }
}
