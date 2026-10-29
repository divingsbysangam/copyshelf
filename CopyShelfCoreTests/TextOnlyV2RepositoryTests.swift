import Foundation
import SwiftData
import Testing
@testable import CopyShelfCore

@Suite @MainActor struct TextOnlyV2RepositoryTests {
    @Test func textOperationsPreserveOtherKinds() async throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let imageID = UUID(), fileID = UUID(), pinnedID = UUID()
        let image = SchemaV2.ClipboardTextItem(id: imageID, createdAt: .now, kind: "image", text: "", isPinned: false)
        image.imageRelativePath = "synthetic-image"
        let file = SchemaV2.ClipboardTextItem(id: fileID, createdAt: .now, kind: "fileReference", text: "", isPinned: false)
        file.fileBookmark = Data([1, 2, 3])
        let pinned = SchemaV2.ClipboardTextItem(id: pinnedID, createdAt: .now, kind: "text", text: "pinned", isPinned: true)
        context.insert(image); context.insert(file); context.insert(pinned)
        try context.save()
        let repo = TextOnlyV2Repository(container: container, policy: RetentionPolicy(unpinnedLimit: 1))
        #expect(try await repo.recentItems().map(\.text) == ["pinned"])
        try await repo.delete(id: imageID)
        try await repo.setPinned(true, id: fileID)
        try await repo.insert(CapturedText(text: "first", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: 1)))
        try await repo.insert(CapturedText(text: "second", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: 2)))
        #expect(Set(try await repo.recentItems().map(\.text)) == Set(["pinned", "second"]))
        try await repo.clear(.all)
        #expect(try await repo.recentItems().isEmpty)
        let remaining = try ModelContext(container).fetch(FetchDescriptor<SchemaV2.ClipboardTextItem>())
        #expect(Set(remaining.map(\.id)) == Set([imageID, fileID]))
        #expect(remaining.first(where: { $0.id == imageID })?.imageRelativePath == "synthetic-image")
        #expect(remaining.first(where: { $0.id == fileID })?.fileBookmark == Data([1, 2, 3]))
        #expect(remaining.allSatisfy { !$0.isPinned })
    }
}
