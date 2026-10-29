import AppKit
import Carbon.HIToolbox
import CopyShelfCore
import Observation

@MainActor
private final class CarbonShortcutBackend: ShortcutBackend {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: @MainActor () -> Void
    private let identifier = EventHotKeyID(signature: 0x43534846, id: 1)

    init(action: @escaping @MainActor () -> Void) { self.action = action }
    func installHandler() -> Bool {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        return InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x43534846, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<CarbonShortcutBackend>.fromOpaque(context).takeUnretainedValue().action() }
            return noErr
        }, 1, &event, context, &handler) == noErr
    }
    func removeHandler() { if let handler { RemoveEventHandler(handler); self.handler = nil } }
    func register(_ shortcut: ShortcutConfiguration) -> Bool {
        guard shortcut.isValid else { return false }
        return RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.modifiers), identifier, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }
    func unregister() { if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil } }
}

@MainActor @Observable
final class ShortcutCoordinator {
    private let lifecycle: ShortcutLifecycle
    private let defaults: UserDefaults
    private var wake: NSObjectProtocol?
    private var termination: NSObjectProtocol?
    var unavailable: Bool { lifecycle.unavailable }
    var configuration: ShortcutConfiguration { lifecycle.configuration }

    init(defaults: UserDefaults = .standard, enabled: Bool = true,
         backend: (any ShortcutBackend)? = nil, action: @escaping @MainActor () -> Void) {
        self.defaults = defaults
        lifecycle = ShortcutLifecycle(backend: backend ?? CarbonShortcutBackend(action: action),
                                      configuration: ShortcutConfiguration.load(from: defaults))
        guard enabled else { return }
        lifecycle.start()
        wake = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lifecycle.wake() }
        }
        termination = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }
    func change(to configuration: ShortcutConfiguration) -> Bool {
        guard lifecycle.change(to: configuration) else { return false }
        configuration.save(to: defaults)
        return true
    }
    func stop() {
        lifecycle.stop()
        if let wake { NSWorkspace.shared.notificationCenter.removeObserver(wake); self.wake = nil }
        if let termination { NotificationCenter.default.removeObserver(termination); self.termination = nil }
    }
}
