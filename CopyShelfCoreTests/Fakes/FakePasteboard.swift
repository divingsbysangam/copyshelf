import CopyShelfCore
import Foundation

/// Reader and writer share one synthetic state, never the system pasteboard.
@MainActor
final class FakePasteboard: PasteboardReading, PasteboardWriting {
    private(set) var changeCount = 0
    private var text: String?
    var types: Set<String> = []
    private(set) var readCount = 0

    func readText() throws -> String? { readCount += 1; return text }
    func availableTypes() -> Set<String> { types }

    @discardableResult
    func writeText(_ text: String) throws -> Int {
        self.text = text
        changeCount += 1
        return changeCount
    }

}
