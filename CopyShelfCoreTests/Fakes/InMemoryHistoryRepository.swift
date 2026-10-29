import CopyShelfCore
import Foundation

/// Contract fixture only. Retention, pruning and disk writes belong to CS-04.
actor InMemoryHistoryRepository: HistoryRepository {
    private var items: [UUID: HistoryItem] = [:]

    func insert(_ capture: CapturedText) async throws -> HistoryItem {
        let item = HistoryItem(id: UUID(), createdAt: capture.capturedAt,
                               text: capture.text, source: capture.source)
        items[item.id] = item
        return item
    }

    func recentItems() async throws -> [HistoryItem] {
        items.values.sorted(by: HistoryOrdering.precedes)
    }

    func setPinned(_ pinned: Bool, id: UUID) async throws {
        guard let item = items[id] else { return }
        items[id] = HistoryItem(id: item.id, createdAt: item.createdAt, kind: item.kind,
                                text: item.text, source: item.source, isPinned: pinned)
    }

    func delete(id: UUID) async throws {
        items.removeValue(forKey: id)
    }

    func clear(_ scope: HistoryClearScope) async throws {
        switch scope {
        case .unpinned: items = items.filter { $0.value.isPinned }
        case .all: items.removeAll()
        }
    }
}
