import AppKit
import CopyShelfCore
import SwiftUI

struct HistoryWindow: View {
    @State var browser: HistoryBrowser
    let settings: AppSettings
    let captureAuthorized: () -> Bool
    let copy: CopyCoordinator?
    let paste: PasteCoordinator?
    let target: () -> PasteTarget?
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Space.md) {
                Image(systemName: "clipboard")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Your clipboard").font(.headline)
                    Text("Saved on this Mac").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(settings.capturePaused ? "Paused" : "Capturing",
                      systemImage: settings.capturePaused ? "pause.fill" : "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
            Divider()
            if let outcome = paste?.outcome {
                HStack {
                    switch outcome {
                    case .shortcutSent: Text("Paste shortcut sent. Check your app.")
                    case .activationFailed: Text("Copied, but the original app could not be activated. Paste in your app.")
                    case .permissionRevoked: Text("Copied, but Accessibility access changed. Paste in your app.")
                    case .targetLost: Text("Copied, but the original app is no longer available. Paste in your app.")
                    case .focusChanged: Text("Copied, but the focused field changed. Paste in your app.")
                    case .eventFailed: Text("Copied, but the paste shortcut could not be created. Paste in your app.")
                    case .consentRequired: Text("Paste is unavailable until you give consent.")
                    case .accessibilityRequired: Text("Accessibility access is needed for paste. You can use Copy instead.")
                    case .targetUnavailable: Text("The original app or focused field is unavailable. Use Copy instead.")
                    case .cancelled: Text("Paste cancelled. Check your clipboard before pasting.")
                    case .busy: Text("A paste request is already in progress.")
                    case .copyFailed: Text("Unable to copy; no paste shortcut was sent.")
                    case .noSelection: Text("Select an item to paste.")
                    }
                    Spacer()
                }.padding(12)
            } else if let outcome = copy?.outcome {
                HStack {
                    switch outcome {
                    case .copied: Text("Copied. Paste in your app.")
                    case .noSelection: Text("Select an item to copy.")
                    case .consentRequired: Text("Copy is unavailable until you give consent.")
                    case .failed: Text("Unable to copy. Try again.")
                    }
                    Spacer()
                }.padding(12)
            }
            if browser.hasError {
                HStack {
                    Text("Unable to load or change history. Try again.")
                    Spacer()
                    Button("Retry") { Task { await browser.refresh() } }
                }
                .padding(12)
            }
            if browser.isLoading && browser.items.isEmpty {
                ProgressView("Loading history…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browser.hasError && browser.items.isEmpty {
                ContentUnavailableView("History unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text("Use Retry to load history again."))
            } else if browser.items.isEmpty {
                ContentUnavailableView("No clipboard history yet", systemImage: "clipboard",
                                       description: Text(!captureAuthorized() ? "Capture is paused until you give consent." :
                                           settings.capturePaused ? "Capture is paused." : "Copied text will appear here."))
            } else if browser.visibleItems.isEmpty {
                if !browser.query.isEmpty {
                    ContentUnavailableView.search(text: browser.query)
                } else {
                    ContentUnavailableView("No Items in This Filter", systemImage: "tray", description: Text("Choose another filter to see history."))
                }
            } else {
                List(browser.visibleItems, selection: $browser.selectedID) { item in
                    HStack(alignment: .top, spacing: Space.md) {
                        Image(systemName: "doc.text")
                            .font(.body)
                            .foregroundStyle(browser.selectedID == item.id ? Color(nsColor: .selectedTextColor) : Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(item.text)
                                .font(.body.weight(.medium))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: Space.sm) {
                                Text(item.source.displayName)
                                    .fontWeight(.medium)
                                Text(item.createdAt, style: .date)
                                Text(item.createdAt, style: .time)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                        Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.fill" : "pin") {
                            Task { await browser.setPinned(!item.isPinned, id: item.id) }
                        }
                        .buttonStyle(.borderless)
                        .labelStyle(.iconOnly)
                        .help(item.isPinned ? "Unpin item" : "Pin item")
                        .accessibilityLabel(item.isPinned ? "Unpin item" : "Pin item")
                    }
                    .padding(Space.md)
                    .background(browser.selectedID == item.id ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12))
                    .listRowSeparator(.hidden)
                    .tag(item.id)
                    .contextMenu {
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            Task { await browser.setPinned(!item.isPinned, id: item.id) }
                        }

                    }
                    .accessibilityAction(named: Text(item.isPinned ? "Unpin" : "Pin")) {
                        Task { await browser.setPinned(!item.isPinned, id: item.id) }
                    }
                }
                .listStyle(.plain)
                .onKeyPress(.return) {
                    guard browser.selectedItem != nil else { return .ignored }
                    guard let paste else { return .ignored }
                    Task { await paste.paste(browser.selectedItem, to: target()) }
                    return .handled
                }

            }
        }
        .onChange(of: browser.selectedID) { _, _ in
            paste?.clearOutcome()
            copy?.clearOutcome()
        }
        .searchable(text: $browser.query, prompt: "Search History")
        .toolbar {
            ToolbarItem {
                Button("Paste Selected", systemImage: "arrow.turn.down.left") {
                    if let paste { Task { await paste.paste(browser.selectedItem, to: target()) } }
                }
                .disabled(browser.selectedItem == nil || paste == nil)
                .help("Paste into the previously focused field")
            }
            ToolbarItem {
                Button("Copy Selected", systemImage: "doc.on.doc") { paste?.clearOutcome(); copy?.copy(browser.selectedItem) }
                    .disabled(browser.selectedItem == nil || copy == nil)
                    .help("Copy the selected item")
            }
            ToolbarItem {
                Button(browser.selectedItem?.isPinned == true ? "Unpin Selected" : "Pin Selected",
                       systemImage: browser.selectedItem?.isPinned == true ? "pin.fill" : "pin") {
                    if let item = browser.selectedItem {
                        Task { await browser.setPinned(!item.isPinned, id: item.id) }
                    }
                }
                .disabled(browser.selectedItem == nil)
                .help("Pin or unpin the selected item")
            }
            ToolbarItem {
                Picker("Filter", selection: $browser.filter) {
                    Text("All").tag(HistoryFilter.all)
                    Text("Pinned").tag(HistoryFilter.pinned)
                    ForEach(browser.sources) { source in
                        Text(source.name).tag(HistoryFilter.source(source.bundleID))
                    }
                }.help("Filter history by pin or source")
            }
            ToolbarItem {
                Button("Clear History", systemImage: "trash") { confirmClear = true }
                    .disabled(browser.items.isEmpty)
                    .help("Clear all history, including pinned items")
            }
        }
        .confirmationDialog("Clear all history, including pinned items?", isPresented: $confirmClear) {
            Button("Clear All", role: .destructive) { Task { await browser.clearAll() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes history from CopyShelf. It is not secure erasure.")
        }
        .frame(minWidth: 400, minHeight: 260)
    }
}

@MainActor
final class HistoryPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
    override func close() { onDismiss?() }
}

@MainActor
final class HistoryWindowController {
    private let fixtureMode: Bool
    init(fixtureMode: Bool = false) { self.fixtureMode = fixtureMode }
    private var panel: HistoryPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var previousTarget: NSRunningApplication?
    private var pasteTarget: PasteTarget?
    private var pasteEnvironment: SystemPasteEnvironment?
    private var pasteCoordinator: PasteCoordinator?
    private lazy var lifecycle = PanelLifecycle(startMonitors: { [weak self] in self?.installMonitors() },
                                                stopMonitors: { [weak self] in self?.removeMonitors() })

    func toggle(runtime: CaptureRuntime, settings: AppSettings) {
        if lifecycle.isVisible { hide(); return }
        show(runtime: runtime, settings: settings)
    }

    func show(runtime: CaptureRuntime, settings: AppSettings) {
        guard let browser = runtime.history else { return }
        guard !lifecycle.isVisible else { return }
        if !fixtureMode, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousTarget = app
        }
        if pasteEnvironment == nil {
            pasteEnvironment = SystemPasteEnvironment(authorized: { [weak self] in self?.fixtureMode == false && runtime.captureAuthorized }, close: { [weak self] in self?.hide() })
            if let copy = runtime.copy, let pasteEnvironment {
                pasteCoordinator = PasteCoordinator(environment: pasteEnvironment, copy: copy)
            }
        }
        if let previousTarget, let pasteEnvironment, runtime.captureAuthorized {
            pasteTarget = pasteEnvironment.snapshot(previousTarget)
        } else { pasteTarget = nil }
        if panel == nil {
            let panel = HistoryPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                                     styleMask: [.titled, .closable, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.title = "CopyShelf History"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isRestorable = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.contentView = NSHostingView(rootView: HistoryWindow(browser: browser, settings: settings, captureAuthorized: { runtime.captureAuthorized }, copy: runtime.copy, paste: pasteCoordinator, target: { [weak self] in self?.pasteTarget }))
            panel.onDismiss = { [weak self] in self?.hide() }
            self.panel = panel
        }
        guard let panel else { return }
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        if let screen { panel.setFrame(PanelGeometry.frame(requested: NSSize(width: 520, height: 360), visible: screen.visibleFrame), display: true) }
        Task { await browser.refresh() }
        panel.orderFrontRegardless()
        panel.makeKey()
        _ = lifecycle.show(targetPID: previousTarget?.processIdentifier)
    }

    private func installMonitors() {
        guard !fixtureMode else { return }
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismissIfOutside() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.dismissIfOutside() }
            return event
        }
    }

    private func dismissIfOutside() {
        guard let panel, panel.isVisible, !panel.frame.contains(NSEvent.mouseLocation) else { return }
        hide()
    }

    func hide() { panel?.orderOut(nil); _ = lifecycle.hide() }
    private func removeMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }
}
