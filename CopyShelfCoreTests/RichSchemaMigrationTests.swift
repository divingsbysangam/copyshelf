import Foundation
import SwiftData
import Testing
@testable import CopyShelfCore

@Suite @MainActor struct RichSchemaMigrationTests {
    @Test func backedUpV1FixtureMigratesWithoutChangingTextOrMetadata() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("CopyShelfMigration-\(UUID())", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let location = StoreLocation(applicationSupport: root)
        try location.prepareDirectory()
        let source = location.storeURL
        let schemaV1 = Schema(versionedSchema: SchemaV1.self)
        let v1Config = ModelConfiguration("CopyShelf", schema: schemaV1, url: source, cloudKitDatabase: .none)
        let v1 = try ModelContainer(for: schemaV1, configurations: [v1Config])
        let context = ModelContext(v1)
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1234)
        let text = "  café\n\t👋  "
        let item = SchemaV1.ClipboardTextItem(id: id, createdAt: date, text: text,
                                              source: SourceApp(bundleID: "fixture.editor", name: "Fixture Editor"),
                                              isPinned: true)
        context.insert(item)
        let secondID = UUID()
        context.insert(SchemaV1.ClipboardTextItem(id: secondID, createdAt: date.addingTimeInterval(1),
                                                  text: "second\n", source: SourceApp(), isPinned: false))
        try context.save()

        let prepared = try await RichStorePreparation.open(location: location)
        let backup = try #require(prepared.backup)
        let migrated = prepared.container
        let rows = try ModelContext(migrated).fetch(FetchDescriptor<SchemaV2.ClipboardTextItem>())
        #expect(rows.count == 2)
        let result = try #require(rows.first(where: { $0.id == id }))
        #expect(result.id == id && result.createdAt == date && result.isPinned)
        #expect(Array(result.text.utf8) == Array(text.utf8))
        #expect(result.kind == "text")
        #expect(result.sourceBundleID == "fixture.editor" && result.sourceAppName == "Fixture Editor")
        #expect(result.imageRelativePath == nil && result.thumbnailRelativePath == nil)
        #expect(result.imageByteCount == nil && result.fileBookmark == nil && result.fileDisplayName == nil)
        #expect(result.imageContentType == nil && result.imageDigest == nil && result.imageWidth == nil && result.imageHeight == nil)
        let second = try #require(rows.first(where: { $0.id == secondID }))
        #expect(second.text == "second\n" && !second.isPinned && second.sourceBundleID == nil && second.sourceAppName == nil)

        let backupConfig = ModelConfiguration("CopyShelf", schema: schemaV1, url: backup, cloudKitDatabase: .none)
        let untouched = try ModelContainer(for: schemaV1, configurations: [backupConfig])
        let backupRows = try ModelContext(untouched).fetch(FetchDescriptor<SchemaV1.ClipboardTextItem>())
        #expect(backupRows.count == 2)
        let saved = try #require(backupRows.first(where: { $0.id == id }))
        #expect(saved.id == id && saved.text == text && saved.isPinned)
        let reopened = try await RichStorePreparation.open(location: location)
        #expect(reopened.backup == backup)
        #expect(try manager.contentsOfDirectory(atPath: location.directory.path)
            .filter { $0.hasPrefix("startup-backup-") } == [])
    }

    @Test func failedBackupDoesNotReplaceCorruptSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfMigration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let location = StoreLocation(applicationSupport: root)
        try location.prepareDirectory()
        let bytes = Data(repeating: 0xA5, count: 4096)
        try bytes.write(to: location.storeURL)
        await #expect(throws: (any Error).self) {
            try await RichStorePreparation.open(location: location)
        }
        #expect(try Data(contentsOf: location.storeURL) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: location.directory.path) == ["CopyShelf.store"])
    }
}
