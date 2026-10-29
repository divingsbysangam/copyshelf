import Observation

@MainActor public protocol ShortcutBackend: AnyObject {
    func installHandler() -> Bool
    func removeHandler()
    func register(_ shortcut: ShortcutConfiguration) -> Bool
    func unregister()
}

@MainActor @Observable
public final class ShortcutLifecycle {
    public private(set) var unavailable = false
    public private(set) var configuration: ShortcutConfiguration
    private var started = false
    private var handlerInstalled = false
    private var registered = false
    private let backend: any ShortcutBackend
    public init(backend: any ShortcutBackend, configuration: ShortcutConfiguration = .standard) {
        self.backend = backend
        self.configuration = configuration
    }

    public func start() {
        guard !started else { return }
        started = true
        handlerInstalled = backend.installHandler()
        guard handlerInstalled else { unavailable = true; return }
        register()
    }

    public func wake() {
        guard started, handlerInstalled else { return }
        if registered { backend.unregister(); registered = false }
        register()
    }

    /// Roll back to the previous shortcut if the requested registration fails.
    @discardableResult public func change(to candidate: ShortcutConfiguration) -> Bool {
        guard candidate.isValid, started, handlerInstalled else { return false }
        if candidate == configuration && registered { return true }
        if registered { backend.unregister(); registered = false }
        if backend.register(candidate) {
            configuration = candidate
            registered = true
            unavailable = false
            return true
        }
        registered = backend.register(configuration)
        unavailable = !registered
        return false
    }

    public func stop() {
        guard started else { return }
        if registered { backend.unregister(); registered = false }
        if handlerInstalled { backend.removeHandler(); handlerInstalled = false }
        started = false
    }

    private func register() {
        registered = backend.register(configuration)
        unavailable = !registered
    }
}
