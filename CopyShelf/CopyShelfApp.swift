import CopyShelfCore
import SwiftUI

@main
struct CopyShelfApp: App {
    #if COPYSHELF_FIXTURE
    @NSApplicationDelegateAdaptor(FixtureAppDelegate.self) private var fixtureDelegate
    #endif
    @State private var settings: AppSettings
    @State private var runtime: CaptureRuntime
    @State private var history: HistoryWindowController
    @State private var shortcut: ShortcutCoordinator
    @State private var exclusions = ExclusionsWindowController()
    @State private var accessibilityHelp = AccessibilityHelpWindowController()
    @State private var consent = CaptureConsentWindowController()
    @State private var shortcutSettings = ShortcutSettingsWindowController()

    init() {
        #if COPYSHELF_FIXTURE
        let settings = AppSettings(defaults: UserDefaults(suiteName: "com.sangam.copyshelf.fixture.settings")!)
        let inMemory = true
        #else
        let settings = AppSettings()
        let inMemory = false
        #endif
        let runtime = CaptureRuntime(settings: settings, inMemory: inMemory)
        let history = HistoryWindowController()
        _settings = State(initialValue: settings)
        _runtime = State(initialValue: runtime)
        _history = State(initialValue: history)
        #if COPYSHELF_FIXTURE
        let enabled = false
        #else
        let enabled = true
        #endif
        _shortcut = State(initialValue: ShortcutCoordinator(enabled: enabled) {
            history.toggle(runtime: runtime, settings: settings)
        })
    }

    var body: some Scene {
        MenuBarExtra("CopyShelf", systemImage: "clipboard") {
            MenuBarContent(settings: settings, history: history, runtime: runtime, exclusions: exclusions, shortcut: shortcut, accessibilityHelp: accessibilityHelp, consent: consent, shortcutSettings: shortcutSettings)
        }
    }
}
