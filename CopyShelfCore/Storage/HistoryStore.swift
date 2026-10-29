import SwiftData

public enum HistoryStore {
    /// Create only one repository for each container, and retain it for the app lifetime.
    public static func openDisk(location: StoreLocation = StoreLocation(),
                                policy: RetentionPolicy = RetentionPolicy()) throws -> SwiftDataHistoryRepository {
        try location.prepareDirectory()
        let container = try ModelContainer(for: StoreLocation.schema,
                                           migrationPlan: CopyShelfMigrationPlan.self,
                                           configurations: [location.diskConfiguration()])
        return SwiftDataHistoryRepository(container: container, policy: policy)
    }

    public static func inMemory(policy: RetentionPolicy = RetentionPolicy()) throws -> SwiftDataHistoryRepository {
        SwiftDataHistoryRepository(container: try StoreLocation.inMemoryContainer(), policy: policy)
    }
}
