public enum HistoryRepositoryError: Error, Sendable, Equatable {
    case saveFailed(domain: String, code: Int)
}
