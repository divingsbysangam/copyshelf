import AppKit
import CopyShelfCore
import SwiftUI

struct MenuBarContent: View {
    let settings: AppSettings
    let history: HistoryWindowController
    let runtime: CaptureRuntime
    let exclusions: ExclusionsWindowController
    let shortcut: ShortcutCoordinator
    let accessibilityHelp: AccessibilityHelpWindowController
    let consent: CaptureConsentWindowController
    let shortcutSettings: ShortcutSettingsWindowController

    var body: some View {
        if shortcut.unavailable {
            Text("Shortcut unavailable — change the shortcut or close the conflicting app.")
        } else {
            Text("Shortcut conflicts with other apps may not be detected.")
        }
        if runtime.unavailable {
            Text("History storage unavailable")
        }
        if let error = runtime.captureError {
            Text(error)
        }
        Button("Show History") {
            history.show(runtime: runtime, settings: settings)
        }
        .disabled(runtime.unavailable)
        if !runtime.captureAuthorized {
            Text("Capture Paused — Consent Required")
            Button("Enable Capture…") { consent.show(runtime: runtime) }.disabled(runtime.unavailable)
        } else {
            Button("Revoke Capture Consent") { Task { await runtime.revoke() } }
        }
        Button(settings.capturePaused ? "Resume Capture" : "Pause Capture") {
            if settings.capturePaused { runtime.resume() }
            else { Task { await runtime.pause() } }
        }
        .disabled(!runtime.captureAuthorized || runtime.unavailable)
        Button("Shortcut Settings…") { shortcutSettings.show(shortcut: shortcut) }
        Button("Excluded Apps…") { exclusions.show(settings: settings) }
        Button("Accessibility for Paste…") { accessibilityHelp.show() }
        Divider()
        Button("Quit CopyShelf") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
