import Foundation

/// One capture-time snapshot. Exact text and source travel together.
public struct CapturedText: Sendable, Equatable {
    public let text: String
    public let source: SourceApp
    public let capturedAt: Date

    public init(text: String, source: SourceApp, capturedAt: Date) {
        self.text = text
        self.source = source
        self.capturedAt = capturedAt
    }
}

/// Detached repository result, safe to send across actors. Never exposes a model.
public struct HistoryItem: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let kind: PayloadKind
    public let text: String
    public let source: SourceApp
    public let isPinned: Bool

    public init(id: UUID, createdAt: Date, kind: PayloadKind = .text,
                text: String, source: SourceApp, isPinned: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.source = source
        self.isPinned = isPinned
    }
}
