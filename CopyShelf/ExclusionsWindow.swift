import AppKit
import CopyShelfCore
import SwiftUI

struct ExclusionsView: View {
    let settings: AppSettings
    @State private var bundleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Excluded Apps").font(.headline).gridProbe("exclusions-title", area: "exclusions")
            Text("Copies from these app bundle IDs are not saved. Sensitive text without a recognized marker cannot be reliably detected; pause capture or exclude apps when needed.")
                .fixedSize(horizontal: false, vertical: true)
                .gridProbe("exclusions-description", area: "exclusions")
            HStack {
                TextField("App bundle ID", text: $bundleID)
                Button("Add App") {
                    let value = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, !settings.excludedBundleIDs.contains(value) else { return }
                    settings.excludedBundleIDs.append(value)
                    bundleID = ""
                }
                .disabled(bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .gridProbe("exclusions-entry", area: "exclusions")
            ScrollView {
                LazyVStack {
                ForEach(settings.excludedBundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).textSelection(.enabled)
                        Spacer()
                        Button("Remove") { settings.excludedBundleIDs.removeAll { $0 == id } }
                            .accessibilityLabel("Remove \(id)")
                    }
                }
                }
            }
        }
        .padding(20)
        .gridArea("exclusions")
        .frame(minWidth: 480, minHeight: 300)
    }
}

@MainActor final class ExclusionsWindowController {
    private var window: NSWindow?
    func show(settings: AppSettings) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Excluded Apps"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentView = NSHostingView(rootView: ExclusionsView(settings: settings))
            window.center()
            self.window = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
