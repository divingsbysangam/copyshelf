import AppKit
import SwiftUI

struct CaptureConsentView: View {
    let runtime: CaptureRuntime
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable Clipboard Capture?").font(.headline)
            Text("CopyShelf will check the clipboard for changes and save future copied text locally on this Mac, up to 1 MiB per item. It will not import the current clipboard when capture starts.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Sensitive text without a recognized marker may be saved. You can pause capture, exclude apps, or revoke consent at any time.")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Not Now") { close() }.keyboardShortcut(.cancelAction)
                Button("Enable Capture") { runtime.authorizeAndResume(); close() }
                    .disabled(runtime.unavailable)
            }
        }.padding(20).frame(minWidth: 480, minHeight: 240)
    }
}

@MainActor final class CaptureConsentWindowController {
    private var window: NSWindow?
    func show(runtime: CaptureRuntime) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Enable Clipboard Capture"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: CaptureConsentView(runtime: runtime, close: { [weak window] in window?.close() }))
            window.center()
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
