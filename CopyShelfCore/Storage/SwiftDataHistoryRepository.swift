import Foundation
import SwiftData

/// Own exactly one repository per container. Context work never suspends inside a mutation.
public actor SwiftDataHistoryRepository: HistoryRepository, ModelActor {
    public nonisolated let modelExecutor: any ModelExecutor
    public nonisolated let modelContainer: ModelContainer
    private let policy: RetentionPolicy
    private let saveHook: @Sendable (ModelContext) throws -> Void

    public init(container: ModelContainer, policy: RetentionPolicy = RetentionPolicy()) {
        self.init(container: container, policy: policy, saveHook: { try $0.save() })
    }

    init(container: ModelContainer, policy: RetentionPolicy = RetentionPolicy(),
         saveHook: @escaping @Sendable (ModelContext) throws -> Void) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.policy = policy
        self.saveHook = saveHook
    }

    private func snapshot(_ item: ClipboardTextItem) -> HistoryItem {
        HistoryItem(id: item.id, createdAt: item.createdAt, text: item.text,
                    source: item.source, isPinned: item.isPinned)
    }

    private func persist() throws {
        do { try saveHook(modelContext) }
        catch {
            modelContext.rollback()
            let error = error as NSError
            throw HistoryRepositoryError.saveFailed(domain: error.domain, code: error.code)
        }
    }

    public func insert(_ capture: CapturedText) async throws -> HistoryItem {
        let item = ClipboardTextItem(createdAt: capture.capturedAt, text: capture.text, source: capture.source)
        let result = snapshot(item)
        modelContext.insert(item)
        do {
            let items = try modelContext.fetch(FetchDescriptor<ClipboardTextItem>())
                .filter { !$0.isPinned }
                .sorted { HistoryOrdering.precedes(snapshot($0), snapshot($1)) }
            for old in items.dropFirst(policy.unpinnedLimit) { modelContext.delete(old) }
            try persist()
        } catch {
            modelContext.rollback()
            throw error
        }
        return result
    }

    public func recentItems() async throws -> [HistoryItem] {
        let descriptor = FetchDescriptor<ClipboardTextItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(snapshot).sorted(by: HistoryOrdering.precedes)
    }

    public func setPinned(_ pinned: Bool, id: UUID) async throws {
        let descriptor = FetchDescriptor<ClipboardTextItem>(predicate: #Predicate { $0.id == id })
        guard let item = try modelContext.fetch(descriptor).first else { return }
        item.isPinned = pinned
        try persist()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<ClipboardTextItem>(predicate: #Predicate { $0.id == id })
        guard let item = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(item)
        try persist()
    }

    public func clear(_ scope: HistoryClearScope) async throws {
        let items = try modelContext.fetch(FetchDescriptor<ClipboardTextItem>())
        for item in items where scope == .all || !item.isPinned { modelContext.delete(item) }
        try persist()
    }
}
