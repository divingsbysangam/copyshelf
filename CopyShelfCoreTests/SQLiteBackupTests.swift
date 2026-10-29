import Foundation
import SQLite3
import Testing
@testable import CopyShelfCore

struct SQLiteBackupTests {
    @Test func includesCommittedWALAndDoesNotOverwriteBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfBackup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.store")
        let destination = root.appendingPathComponent("backup.store")
        var db: OpaquePointer?
        #expect(sqlite3_open(source.path, &db) == SQLITE_OK)
        let handle = try #require(db)
        defer { sqlite3_close(handle) }
        #expect(sqlite3_exec(handle, "PRAGMA journal_mode=WAL; CREATE TABLE fixture(value TEXT); INSERT INTO fixture VALUES ('synthetic');", nil, nil, nil) == SQLITE_OK)
        #expect(FileManager.default.fileExists(atPath: source.path + "-wal"))
        let backup = SQLiteBackup()
        try await backup.create(source: source, destination: destination)
        let originalBytes = try Data(contentsOf: destination)
        await #expect(throws: SQLiteBackupError.destinationExistsOrUnavailable) {
            try await backup.create(source: source, destination: destination)
        }
        #expect(try Data(contentsOf: destination) == originalBytes)
        var copy: OpaquePointer?
        #expect(sqlite3_open_v2(destination.path, &copy, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        let copyDB = try #require(copy)
        defer { sqlite3_close(copyDB) }
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(copyDB, "SELECT value FROM fixture", -1, &statement, nil) == SQLITE_OK)
        let query = try #require(statement)
        defer { sqlite3_finalize(query) }
        #expect(sqlite3_step(query) == SQLITE_ROW)
        #expect(String(cString: try #require(sqlite3_column_text(query, 0))) == "synthetic")
    }

    @Test func missingSourceDoesNotLeaveBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfBackup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.store")
        await #expect(throws: SQLiteBackupError.sourceUnavailable) {
            try await SQLiteBackup().create(source: root.appendingPathComponent("missing.store"), destination: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func corruptSourceDoesNotLeaveBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfBackup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.store")
        let destination = root.appendingPathComponent("backup.store")
        try Data(repeating: 0xA5, count: 4096).write(to: source)
        await #expect(throws: (any Error).self) {
            try await SQLiteBackup().create(source: source, destination: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func existingSidecarIsNeverOverwrittenOrRemoved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfBackup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("backup.store")
        let sidecar = URL(fileURLWithPath: destination.path + "-wal")
        try Data([42]).write(to: sidecar)
        await #expect(throws: SQLiteBackupError.destinationExistsOrUnavailable) {
            try await SQLiteBackup().create(source: root.appendingPathComponent("missing"), destination: destination)
        }
        #expect(try Data(contentsOf: sidecar) == Data([42]))
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
