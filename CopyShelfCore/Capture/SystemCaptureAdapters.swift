import AppKit
import Foundation

public struct SystemCaptureClock: CaptureClock {
    public init() {}
    public func now() -> Date { Date() }
}

@MainActor
public struct SystemPasteboardReader: PasteboardReading {
    public init() {}
    public var changeCount: Int { NSPasteboard.general.changeCount }
    public func readText() throws -> String? { NSPasteboard.general.string(forType: .string) }
    public func availableTypes() -> Set<String> {
        Set((NSPasteboard.general.pasteboardItems ?? []).flatMap { $0.types.map(\.rawValue) })
    }
}

@MainActor
public struct SystemSourceAppProvider: SourceAppProviding {
    public init() {}
    public func frontmostSource() -> SourceApp {
        let app = NSWorkspace.shared.frontmostApplication
        return SourceApp(bundleID: app?.bundleIdentifier, name: app?.localizedName)
    }
}

@MainActor
public struct SystemPasteboardWriter: PasteboardWriting {
    public init() {}
    public func writeText(_ text: String) throws -> Int {
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(text, forType: .string) else { throw ClipboardWriteError.failed }
        return board.changeCount
    }
}

public enum ClipboardWriteError: Error { case failed }
