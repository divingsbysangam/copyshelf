import Foundation
import SwiftData

public struct StoreLocation: Sendable {
    public let applicationSupport: URL

    public init(applicationSupport: URL = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    )[0]) {
        self.applicationSupport = applicationSupport
    }

    public var directory: URL {
        applicationSupport.appendingPathComponent("CopyShelf", isDirectory: true)
    }

    public var storeURL: URL {
        directory.appendingPathComponent("CopyShelf.store", isDirectory: false)
    }

    /// Called by the future disk repository, never by today's app shell.
    public func prepareDirectory() throws {
        let manager = FileManager.default
        let values = try? directory.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Also enforce the contract when an existing own directory is reused.
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    public static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    public func diskConfiguration() -> ModelConfiguration {
        // SwiftData's explicit-URL initializer selects no group container; unlike
        // its location-inference initializer it has no groupContainer argument.
        ModelConfiguration("CopyShelf", schema: Self.schema, url: storeURL, cloudKitDatabase: .none)
    }

    public static func memoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            "CopyShelfTests", schema: schema, isStoredInMemoryOnly: true,
            groupContainer: .none, cloudKitDatabase: .none
        )
    }

    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema, migrationPlan: CopyShelfMigrationPlan.self,
            configurations: [memoryConfiguration()]
        )
    }
}
