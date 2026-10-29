public enum HistoryOrdering {
    public static func precedes(_ lhs: HistoryItem, _ rhs: HistoryItem) -> Bool {
        if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.createdAt > rhs.createdAt
    }
}
