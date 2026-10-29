import AppKit
import SwiftUI

struct AccessibilityHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility for Paste").font(.headline)
            Text("CopyShelf can copy an item without Accessibility access. To send the paste shortcut to the field you were using, grant Accessibility access to the installed CopyShelf app after approving the local test.")
                .fixedSize(horizontal: false, vertical: true)
            Text("You can deny or remove access at any time. If the original app or field changes, CopyShelf will not send the shortcut.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Accessibility Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }.padding(20).frame(minWidth: 480, minHeight: 200, alignment: .topLeading)
    }
}

@MainActor final class AccessibilityHelpWindowController {
    private var window: NSWindow?
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Accessibility for Paste"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: AccessibilityHelpView())
            window.center()
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
