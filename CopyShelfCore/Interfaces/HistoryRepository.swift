import Foundation

public enum HistoryClearScope: Sendable {
    case unpinned
    case all
}

/// CS-04 supplies the single-owner persistent implementation. All mutations
/// report failures, and values crossing the boundary are detached snapshots.
public protocol HistoryRepository: Sendable {
    @discardableResult
    func insert(_ capture: CapturedText) async throws -> HistoryItem
    /// Newest timestamp first. Equal timestamps sort by UUID string ascending.
    func recentItems() async throws -> [HistoryItem]
    /// Unknown IDs are a no-op for both set-pin and delete.
    func setPinned(_ pinned: Bool, id: UUID) async throws
    func delete(id: UUID) async throws
    func clear(_ scope: HistoryClearScope) async throws
}
