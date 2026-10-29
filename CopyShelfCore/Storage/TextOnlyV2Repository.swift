import Foundation
import SwiftData

/// Reads and changes only text rows, retaining any older non-text rows.
public actor TextOnlyV2Repository: HistoryRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer
    private let policy: RetentionPolicy

    public init(container: ModelContainer, policy: RetentionPolicy = RetentionPolicy()) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.policy = policy
    }

    private func rows() throws -> [SchemaV2.ClipboardTextItem] {
        try modelContext.fetch(FetchDescriptor<SchemaV2.ClipboardTextItem>()).filter { $0.kind == "text" }
    }

    private func snapshot(_ item: SchemaV2.ClipboardTextItem) -> HistoryItem {
        HistoryItem(id: item.id, createdAt: item.createdAt, text: item.text,
                    source: SourceApp(bundleID: item.sourceBundleID, name: item.sourceAppName), isPinned: item.isPinned)
    }

    public func recentItems() throws -> [HistoryItem] {
        try rows().map(snapshot).sorted(by: HistoryOrdering.precedes)
    }

    public func insert(_ capture: CapturedText) throws -> HistoryItem {
        let item = SchemaV2.ClipboardTextItem(id: UUID(), createdAt: capture.capturedAt,
                                              kind: "text", text: capture.text, isPinned: false)
        item.sourceBundleID = capture.source.bundleID
        item.sourceAppName = capture.source.name
        let result = snapshot(item)
        modelContext.insert(item)
        do {
            let unpinned = try rows().filter { !$0.isPinned }.sorted {
                HistoryOrdering.precedes(snapshot($0), snapshot($1))
            }
            for old in unpinned.dropFirst(policy.unpinnedLimit) { modelContext.delete(old) }
            try modelContext.save()
            return result
        } catch { modelContext.rollback(); throw error }
    }

    public func setPinned(_ pinned: Bool, id: UUID) throws {
        guard let item = try rows().first(where: { $0.id == id }) else { return }
        item.isPinned = pinned
        do { try modelContext.save() } catch { modelContext.rollback(); throw error }
    }
    public func delete(id: UUID) throws {
        guard let item = try rows().first(where: { $0.id == id }) else { return }
        modelContext.delete(item)
        do { try modelContext.save() } catch { modelContext.rollback(); throw error }
    }
    public func clear(_ scope: HistoryClearScope) throws {
        for item in try rows() where scope == .all || !item.isPinned { modelContext.delete(item) }
        do { try modelContext.save() } catch { modelContext.rollback(); throw error }
    }
}
