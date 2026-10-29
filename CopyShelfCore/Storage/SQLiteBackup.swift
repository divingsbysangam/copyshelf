import Darwin
import Foundation
import SQLite3

public enum SQLiteBackupError: Error, Equatable {
    case destinationExistsOrUnavailable
    case sourceUnavailable
    case destinationUnavailable
    case snapshotFailed
    case integrityCheckFailed
}

/// Creates a consistent SQLite snapshot, including committed WAL transactions.
/// Callers must stop the repository writer and choose an app-owned destination.
public actor SQLiteBackup {
    public init() {}

    public func create(source: URL, destination: URL) throws {
        for suffix in ["-wal", "-shm"] {
            var info = stat()
            if lstat(destination.path + suffix, &info) == 0 || errno != ENOENT {
                throw SQLiteBackupError.destinationExistsOrUnavailable
            }
        }
        let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw SQLiteBackupError.destinationExistsOrUnavailable }
        close(descriptor)
        var succeeded = false
        defer {
            if !succeeded {
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(atPath: destination.path + suffix)
                }
            }
        }

        var sourceDB: OpaquePointer?
        guard sqlite3_open_v2(source.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let sourceDB else {
            if let sourceDB { sqlite3_close(sourceDB) }
            throw SQLiteBackupError.sourceUnavailable
        }
        defer { sqlite3_close(sourceDB) }

        var destinationDB: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &destinationDB, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let destinationDB else {
            if let destinationDB { sqlite3_close(destinationDB) }
            throw SQLiteBackupError.destinationUnavailable
        }
        defer { sqlite3_close(destinationDB) }
        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw SQLiteBackupError.snapshotFailed
        }
        let status = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard status == SQLITE_DONE, finish == SQLITE_OK else { throw SQLiteBackupError.snapshotFailed }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(destinationDB, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK,
              let statement else { throw SQLiteBackupError.integrityCheckFailed }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let result = sqlite3_column_text(statement, 0),
              String(cString: result) == "ok",
              sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteBackupError.integrityCheckFailed }
        succeeded = true
    }
}
