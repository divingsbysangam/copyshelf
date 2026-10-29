import Foundation
import SwiftData

/// Candidate schema for V2. Production remains on V1 until backup and
/// rich-payload lifecycle handling are connected and verified.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [ClipboardTextItem.self] }

    @Model public final class ClipboardTextItem {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var kind: String
        public var text: String
        public var sourceBundleID: String?
        public var sourceAppName: String?
        public var isPinned: Bool
        public var imageRelativePath: String?
        public var thumbnailRelativePath: String?
        public var imageByteCount: Int64?
        public var imageContentType: String?
        public var imageDigest: Data?
        public var imageWidth: Int?
        public var imageHeight: Int?
        public var fileBookmark: Data?
        public var fileDisplayName: String?

        public init(id: UUID, createdAt: Date, kind: String, text: String, isPinned: Bool) {
            self.id = id
            self.createdAt = createdAt
            self.kind = kind
            self.text = text
            self.isPinned = isPinned
        }
    }
}

public enum RichHistoryMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    public static var stages: [MigrationStage] { [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)] }
}
