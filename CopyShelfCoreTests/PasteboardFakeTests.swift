import CopyShelfCore
import Foundation
import Testing

@MainActor
struct PasteboardFakeTests {
    @Test func readerAndWriterShareRestoreCount() throws {
        let fake = FakePasteboard()
        let reader: any PasteboardReading = fake
        let writer: any PasteboardWriting = fake
        #expect(reader.changeCount == 0)
        #expect(try reader.readText() == nil)
        let text = "  synthetic\n👋  "
        #expect(try writer.writeText(text) == 1)
        #expect(reader.changeCount == 1)
        #expect(try reader.readText() == text)
        #expect(try writer.writeText(text) == 2)
        #expect(reader.changeCount == 2)
    }

    @Test func sourceAndTimeFormOneDetachedCapture() async throws {
        var source = FakeSourceAppProvider()
        #expect(source.frontmostSource().displayName == "Unknown")
        source.source = SourceApp(bundleID: "test.synthetic.editor", name: "Fixture Editor")
        var clock = FakeClock()
        clock.date = Date(timeIntervalSince1970: 42)
        let capture = CapturedText(text: "fixture", source: source.frontmostSource(), capturedAt: clock.now())
        source.source = SourceApp()
        clock.date = Date(timeIntervalSince1970: 99)
        let item = try await InMemoryHistoryRepository().insert(capture)
        #expect(item.source.bundleID == "test.synthetic.editor")
        #expect(item.source.displayName == "Fixture Editor")
        #expect(item.createdAt == Date(timeIntervalSince1970: 42))
    }
}
