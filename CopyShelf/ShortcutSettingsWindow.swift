import AppKit
import Carbon.HIToolbox
import CopyShelfCore
import SwiftUI

private struct LetterKey: Identifiable {
    let name: String
    let code: Int
    var id: Int { code }
}

private let letterKeys: [LetterKey] = [
    .init(name: "A", code: Int(kVK_ANSI_A)), .init(name: "B", code: Int(kVK_ANSI_B)),
    .init(name: "C", code: Int(kVK_ANSI_C)), .init(name: "D", code: Int(kVK_ANSI_D)),
    .init(name: "E", code: Int(kVK_ANSI_E)), .init(name: "F", code: Int(kVK_ANSI_F)),
    .init(name: "G", code: Int(kVK_ANSI_G)), .init(name: "H", code: Int(kVK_ANSI_H)),
    .init(name: "I", code: Int(kVK_ANSI_I)), .init(name: "J", code: Int(kVK_ANSI_J)),
    .init(name: "K", code: Int(kVK_ANSI_K)), .init(name: "L", code: Int(kVK_ANSI_L)),
    .init(name: "M", code: Int(kVK_ANSI_M)), .init(name: "N", code: Int(kVK_ANSI_N)),
    .init(name: "O", code: Int(kVK_ANSI_O)), .init(name: "P", code: Int(kVK_ANSI_P)),
    .init(name: "Q", code: Int(kVK_ANSI_Q)), .init(name: "R", code: Int(kVK_ANSI_R)),
    .init(name: "S", code: Int(kVK_ANSI_S)), .init(name: "T", code: Int(kVK_ANSI_T)),
    .init(name: "U", code: Int(kVK_ANSI_U)), .init(name: "V", code: Int(kVK_ANSI_V)),
    .init(name: "W", code: Int(kVK_ANSI_W)), .init(name: "X", code: Int(kVK_ANSI_X)),
    .init(name: "Y", code: Int(kVK_ANSI_Y)), .init(name: "Z", code: Int(kVK_ANSI_Z))
]

struct ShortcutSettingsView: View {
    let shortcut: ShortcutCoordinator
    let close: () -> Void
    @State private var draft: ShortcutConfiguration
    @State private var message: String?

    init(shortcut: ShortcutCoordinator, close: @escaping () -> Void) {
        self.shortcut = shortcut
        self.close = close
        _draft = State(initialValue: shortcut.configuration)
    }

    private func modifier(_ bit: Int) -> Binding<Bool> {
        Binding(get: { draft.modifiers & bit != 0 }, set: { enabled in
            if enabled { draft.modifiers |= bit } else { draft.modifiers &= ~bit }
            message = nil
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open CopyShelf").font(.headline).gridProbe("shortcut-title", area: "shortcut")
            Text("Choose a key and at least one modifier. The shortcut opens or closes history.")
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("shortcut-intro", area: "shortcut")
            Picker("Key", selection: $draft.keyCode) {
                if !letterKeys.contains(where: { $0.code == draft.keyCode }) {
                    Text("Key code \(draft.keyCode)").tag(draft.keyCode)
                }
                ForEach(letterKeys) { key in Text(key.name).tag(key.code) }
            }
            .gridProbe("shortcut-key", area: "shortcut")
            HStack(spacing: 16) {
                Toggle("Control", isOn: modifier(ShortcutConfiguration.control))
                Toggle("Option", isOn: modifier(ShortcutConfiguration.option))
                Toggle("Shift", isOn: modifier(ShortcutConfiguration.shift))
                Toggle("Command", isOn: modifier(ShortcutConfiguration.command))
            }
            .gridProbe("shortcut-modifiers", area: "shortcut")
            Text("Key labels use US keyboard positions. Other apps may use the same shortcut without macOS reporting a conflict; test your choice in your usual apps.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("shortcut-warning", area: "shortcut")
            if let message { Text(message).foregroundStyle(shortcut.unavailable ? .red : .secondary) }
            HStack {
                Button("Reset to Default") { draft = .standard; message = nil }
                Spacer()
                Button("Close") { close() }.keyboardShortcut(.cancelAction)
                Button("Save Shortcut") {
                    if shortcut.change(to: draft) {
                        message = "Shortcut saved."
                    } else {
                        message = shortcut.unavailable
                            ? "Could not register the shortcut or restore the previous one."
                            : "Could not register the shortcut. The previous shortcut is still active."
                    }
                }.disabled(!draft.isValid)
            }
        }
        .padding(20)
        .gridArea("shortcut")
        .frame(minWidth: 520, minHeight: 280, alignment: .topLeading)
        .onAppear { draft = shortcut.configuration; message = nil }
        .onChange(of: draft.keyCode) { _, _ in message = nil }
    }
}

@MainActor final class ShortcutSettingsWindowController {
    private var window: NSWindow?
    func show(shortcut: ShortcutCoordinator) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Shortcut Settings"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentView = NSHostingView(rootView: ShortcutSettingsView(shortcut: shortcut, close: { [weak window] in window?.close() }))
            window.center()
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
