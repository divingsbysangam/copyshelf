import Foundation
import SwiftData
import Testing
@testable import CopyShelfCore

@MainActor
struct ModelTests {
    @Test func exactTextAndMetadataRoundTrip() throws {
        let container = try StoreLocation.inMemoryContainer()
        let context = ModelContext(container)
        let text = "  héllo\n\tworld 👋  "
        let source = SourceApp(bundleID: "test.synthetic.editor", name: "Fixture Editor")
        let time = Date(timeIntervalSince1970: 100)
        let item = ClipboardTextItem(createdAt: time, text: text, source: source)
        context.insert(item)
        try context.save()

        // Fetch through a fresh context to exercise persisted model fields.
        let fetched = try ModelContext(container).fetch(FetchDescriptor<ClipboardTextItem>())
        let result = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(Array(result.text.utf8) == Array(text.utf8))
        #expect(result.id == item.id)
        #expect(result.createdAt == time)
        #expect(result.source == source)
        #expect(result.kind == PayloadKind.text.rawValue)
        #expect(!result.isPinned)
    }

    @Test func unknownSourceAndNewestFirst() throws {
        let container = try StoreLocation.inMemoryContainer()
        let context = ModelContext(container)
        let older = ClipboardTextItem(createdAt: Date(timeIntervalSince1970: 1), text: "older")
        let newer = ClipboardTextItem(createdAt: Date(timeIntervalSince1970: 2), text: "newer", isPinned: true)
        context.insert(newer)
        context.insert(older)
        try context.save()
        let fetched = try ModelContext(container).fetch(FetchDescriptor<ClipboardTextItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        #expect(fetched.map(\.id) == [newer.id, older.id])
        #expect(newer.id != older.id)
        #expect(fetched[0].isPinned)
        #expect(fetched[1].sourceBundleID == nil)
        #expect(fetched[1].sourceAppName == nil)
        #expect(fetched[1].source.displayName == "Unknown")
    }
}
