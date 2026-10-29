import Foundation
import SwiftData

public struct PreparedRichStore {
    public let container: ModelContainer
    public let backup: URL?
}

/// Preparation only; the caller must ensure the old writer is stopped before
/// invoking this. It is not used by the app until rich storage is integrated.
public enum RichStorePreparation {
    public static func open(location: StoreLocation, backupService: SQLiteBackup = SQLiteBackup()) async throws -> PreparedRichStore {
        try location.prepareDirectory()
        let source = location.storeURL
        var backup: URL?
        var temporaryBackup: URL?
        if FileManager.default.fileExists(atPath: source.path) {
            let original = location.directory.appendingPathComponent("pre-v2-backup.store")
            let exists = FileManager.default.fileExists(atPath: original.path)
            let candidate = exists ? location.directory.appendingPathComponent("startup-backup-\(UUID().uuidString).store") : original
            for suffix in ["-wal", "-shm"] where FileManager.default.fileExists(atPath: candidate.path + suffix) {
                throw SQLiteBackupError.destinationExistsOrUnavailable
            }
            try await backupService.create(source: source, destination: candidate)
            backup = candidate
            if exists { temporaryBackup = candidate }
        }
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration = ModelConfiguration("CopyShelf", schema: schema, url: source, cloudKitDatabase: .none)
        // A failed migration deliberately leaves the verified backup in place.
        let container = try ModelContainer(for: schema, migrationPlan: RichHistoryMigrationPlan.self,
                                           configurations: [configuration])
        // Retain the first backup permanently. Later successful opens may discard
        // their just-created snapshot; failed opens retain it for recovery.
        if let temporaryBackup {
            for suffix in ["", "-wal", "-shm"] {
                let file = URL(fileURLWithPath: temporaryBackup.path + suffix)
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            }
            backup = location.directory.appendingPathComponent("pre-v2-backup.store")
        }
        return PreparedRichStore(container: container, backup: backup)
    }
}
