import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [ClipboardTextItem.self] }

    @Model
    public final class ClipboardTextItem {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        /// Raw storage keeps later payload kinds additive to the versioned schema.
        public var kind: String
        public var text: String
        public var sourceBundleID: String?
        public var sourceAppName: String?
        public var isPinned: Bool

        public init(
            id: UUID = UUID(),
            createdAt: Date,
            text: String,
            source: SourceApp = SourceApp(),
            isPinned: Bool = false
        ) {
            self.id = id
            self.createdAt = createdAt
            self.kind = PayloadKind.text.rawValue
            self.text = text
            self.sourceBundleID = source.bundleID
            self.sourceAppName = source.name
            self.isPinned = isPinned
        }

        public var source: SourceApp {
            SourceApp(bundleID: sourceBundleID, name: sourceAppName)
        }
    }
}

public typealias ClipboardTextItem = SchemaV1.ClipboardTextItem
