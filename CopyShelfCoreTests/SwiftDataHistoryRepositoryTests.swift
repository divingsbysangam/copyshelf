import CopyShelfCore
import Foundation
import Testing

struct SwiftDataHistoryRepositoryTests {
    private func runContract(disk: Bool, _ test: (HistoryRepositoryContract<SwiftDataHistoryRepository>) async throws -> Void) async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        let contract = HistoryRepositoryContract<SwiftDataHistoryRepository>(makeRepository: {
            if disk { return try HistoryStore.openDisk(location: StoreLocation(applicationSupport: base.appendingPathComponent(UUID().uuidString))) }
            return try HistoryStore.inMemory()
        })
        try await test(contract)
    }

    @Test(arguments: [false, true]) func contract(disk: Bool) async throws {
        try await runContract(disk: disk) { contract in
            try await contract.insertAndOrder()
            try await contract.pinOnlyTarget()
            try await contract.clearPreservesPinsOnlyWhenRequested()
            try await contract.deletionAndUnknownIDs()
            try await contract.equalTimestampsHaveStableOrdering()
        }
    }

    @Test func restartPreservesSnapshots() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        let location = StoreLocation(applicationSupport: base)
        var expected: [HistoryItem] = []
        do {
            let repository = try HistoryStore.openDisk(location: location)
            for i in 0..<3 {
                let item = try await repository.insert(CapturedText(text: " fixture \(i) é\n", source: SourceApp(bundleID: "synthetic.editor", name: "Fixture"), capturedAt: Date(timeIntervalSince1970: Double(i))))
                if i == 1 { try await repository.setPinned(true, id: item.id) }
            }
            expected = try await repository.recentItems()
        }
        let reopened = try HistoryStore.openDisk(location: location)
        #expect(try await reopened.recentItems() == expected)
        #expect(FileManager.default.fileExists(atPath: location.storeURL.path))
        let permissions = try FileManager.default.attributesOfItem(atPath: location.directory.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o700)
    }
}
