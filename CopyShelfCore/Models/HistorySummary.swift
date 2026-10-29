public struct HistorySummary: Sendable, Equatable {
    public let total: Int
    public let pinned: Int
    public let unpinned: Int
    public let limit: Int

    public init(items: [HistoryItem], policy: RetentionPolicy) {
        total = items.count
        pinned = items.filter(\.isPinned).count
        unpinned = total - pinned
        limit = policy.unpinnedLimit
    }
}
