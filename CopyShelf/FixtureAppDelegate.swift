#if COPYSHELF_FIXTURE
import AppKit
import CopyShelfCore
import SwiftUI

@MainActor final class FixtureAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var exclusionsWindow: NSWindow?
    private var fixturePanel: HistoryWindowController?
    private var fixtureAccessibility: NSWindow?
    private var fixtureConsent: NSWindow?
    private var fixtureShortcut: NSWindow?
    private var fixtureShortcutCoordinator: ShortcutCoordinator?
    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults(suiteName: "com.sangam.copyshelf.fixture.settings")?.removePersistentDomain(forName: "com.sangam.copyshelf.fixture.settings")
        UserDefaults(suiteName: "com.sangam.copyshelf.fixture.ui")?.removePersistentDomain(forName: "com.sangam.copyshelf.fixture.ui")
        UserDefaults(suiteName: "com.sangam.copyshelf.fixture.shortcut")?.removePersistentDomain(forName: "com.sangam.copyshelf.fixture.shortcut")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if COPYSHELF_FIXTURE_LIGHT
        NSApp.appearance = NSAppearance(named: .aqua)
        #elseif COPYSHELF_FIXTURE_DARK
        NSApp.appearance = NSAppearance(named: .darkAqua)
        #endif
        Task { @MainActor in
            do {
                let repository = try HistoryStore.inMemory()
                _ = try await repository.insert(CapturedText(text: "Synthetic history item\nA second line for testing", source: SourceApp(bundleID: "fixture.editor", name: "Fixture Editor"), capturedAt: Date()))
                _ = try await repository.insert(CapturedText(text: "Unicode fixture: café 👋", source: SourceApp(), capturedAt: Date().addingTimeInterval(-60)))
                #if COPYSHELF_FIXTURE_MANY
                for i in 0..<198 {
                    _ = try await repository.insert(CapturedText(text: "Synthetic item \(i)", source: SourceApp(bundleID: "fixture.app", name: "Fixture"), capturedAt: Date().addingTimeInterval(-Double(i + 120))))
                }
                #endif
                let fixtureBoard = FixturePasteboard()
                let fixtureCapture = TextCapture(pasteboard: fixtureBoard, sources: FixtureSource(), clock: SystemCaptureClock(), repository: repository)
                let fixtureCopy = CopyCoordinator(writer: fixtureBoard, capture: fixtureCapture, isAuthorized: { true })
                let browser = HistoryBrowser(repository: repository)
                await browser.refresh()
                let defaults = UserDefaults(suiteName: "com.sangam.copyshelf.fixture.ui")!
                let settings = AppSettings(defaults: defaults)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "CopyShelf Fixture History"
                window.contentView = NSHostingView(rootView: HistoryWindow(browser: browser, settings: settings, captureAuthorized: { false }, copy: fixtureCopy, paste: nil, target: { nil }))
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.window = window
                settings.excludedBundleIDs = ["fixture.example.app"]
                let exclusions = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                exclusions.title = "CopyShelf Fixture Exclusions"
                exclusions.contentView = NSHostingView(rootView: ExclusionsView(settings: settings))
                exclusions.center()
                exclusions.makeKeyAndOrderFront(nil)
                self.exclusionsWindow = exclusions
                #if COPYSHELF_FIXTURE_SHORTCUT
                let shortcutDefaults = UserDefaults(suiteName: "com.sangam.copyshelf.fixture.shortcut")!
                shortcutDefaults.removePersistentDomain(forName: "com.sangam.copyshelf.fixture.shortcut")
                let fixtureShortcut = ShortcutCoordinator(defaults: shortcutDefaults, backend: FixtureShortcutBackend()) {}
                self.fixtureShortcutCoordinator = fixtureShortcut
                let shortcutWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                shortcutWindow.title = "Shortcut Settings"
                shortcutWindow.contentView = NSHostingView(rootView: ShortcutSettingsView(shortcut: fixtureShortcut, close: { [weak shortcutWindow] in shortcutWindow?.close() }))
                shortcutWindow.center()
                shortcutWindow.makeKeyAndOrderFront(nil)
                self.fixtureShortcut = shortcutWindow
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let path = FileManager.default.temporaryDirectory.appendingPathComponent("copyshelf-shortcut-layout.json").path
                    GridProbes.shared.write(to: path, window: shortcutWindow.contentView?.bounds.size ?? .zero)
                }
                #endif
                #if COPYSHELF_FIXTURE_CONSENT
                let consentRuntime = CaptureRuntime(settings: settings, inMemory: true)
                let consent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                consent.title = "Enable Clipboard Capture"
                consent.contentView = NSHostingView(rootView: CaptureConsentView(runtime: consentRuntime, close: {}))
                consent.center()
                consent.makeKeyAndOrderFront(nil)
                self.fixtureConsent = consent
                #endif
                #if COPYSHELF_FIXTURE_AX
                let help = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                help.title = "Accessibility for Paste"
                help.contentView = NSHostingView(rootView: AccessibilityHelpView())
                help.center()
                help.makeKeyAndOrderFront(nil)
                self.fixtureAccessibility = help
                #endif
                #if COPYSHELF_FIXTURE_PANEL
                let panel = HistoryWindowController(fixtureMode: true)
                let runtime = CaptureRuntime(settings: settings, inMemory: true)
                panel.show(runtime: runtime, settings: settings)
                self.fixturePanel = panel
                #endif
                #if COPYSHELF_FIXTURE_HISTORY_FRONT
                window.makeKeyAndOrderFront(nil)
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let path = FileManager.default.temporaryDirectory.appendingPathComponent("copyshelf-fixture-exclusions-layout.json").path
                    GridProbes.shared.write(to: path, window: exclusions.contentView?.bounds.size ?? .zero)
                }
            } catch { NSApp.terminate(nil) }
        }
    }
}
@MainActor private final class FixturePasteboard: PasteboardReading, PasteboardWriting {
    private(set) var changeCount = 0
    private var text: String?
    func readText() throws -> String? { text }
    func writeText(_ text: String) throws -> Int { self.text = text; changeCount += 1; return changeCount }
}
@MainActor private struct FixtureSource: SourceAppProviding {
    func frontmostSource() -> SourceApp { SourceApp() }
}
@MainActor private final class FixtureShortcutBackend: ShortcutBackend {
    func installHandler() -> Bool { true }
    func removeHandler() {}
    func register(_ shortcut: ShortcutConfiguration) -> Bool { true }
    func unregister() {}
}
#endif
