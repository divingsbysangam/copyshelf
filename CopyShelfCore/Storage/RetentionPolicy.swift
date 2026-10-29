public struct RetentionPolicy: Sendable, Equatable {
    public static let defaultLimit = 200
    public static let maximumLimit = 1000
    public let unpinnedLimit: Int

    public init(unpinnedLimit: Int = Self.defaultLimit) {
        self.unpinnedLimit = min(max(unpinnedLimit, 1), Self.maximumLimit)
    }
}
