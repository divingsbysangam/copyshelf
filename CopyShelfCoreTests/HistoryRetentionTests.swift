import CopyShelfCore
import Foundation
import Testing

struct HistoryRetentionTests {
    private func capture(_ time: Int) -> CapturedText {
        CapturedText(text: "synthetic \(time)", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: Double(time)))
    }

    @Test func retentionPinsUnpinAndOldCapture() async throws {
        let repo = try HistoryStore.inMemory(policy: RetentionPolicy(unpinnedLimit: 3))
        let pin = try await repo.insert(capture(0))
        try await repo.setPinned(true, id: pin.id)
        for i in 1...5 { try await repo.insert(capture(i)) }
        var items = try await repo.recentItems()
        #expect(items.map(\.createdAt) == [5, 4, 3, 0].map { Date(timeIntervalSince1970: Double($0)) })
        #expect(items.last?.isPinned == true)
        try await repo.setPinned(false, id: pin.id)
        #expect(try await repo.recentItems().count == 4)
        try await repo.insert(capture(6))
        items = try await repo.recentItems()
        #expect(items.count == 3 && !items.contains { $0.id == pin.id })
        let old = try await repo.insert(capture(-1))
        #expect(try await !repo.recentItems().contains { $0.id == old.id })
    }

    @Test func concurrentInsertsRemainBounded() async throws {
        let repo = try HistoryStore.inMemory(policy: RetentionPolicy(unpinnedLimit: 10))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 {
                group.addTask { try await repo.insert(CapturedText(text: "fixture", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: Double(i)))) }
            }
            try await group.waitForAll()
        }
        let items = try await repo.recentItems()
        #expect(items.count == 10)
        #expect(items.map(\.createdAt) == (30..<40).reversed().map { Date(timeIntervalSince1970: Double($0)) })
    }

    @Test func timestampTiesPruneLastUUID() async throws {
        let repo = try HistoryStore.inMemory(policy: RetentionPolicy(unpinnedLimit: 2))
        let inserted = try await [repo.insert(capture(1)), repo.insert(capture(1)), repo.insert(capture(1))]
        #expect(try await repo.recentItems() == Array(inserted.sorted(by: HistoryOrdering.precedes).prefix(2)))
    }

    @Test func defaultLimitIsEnforced() async throws {
        let repo = try HistoryStore.inMemory()
        for i in 0..<205 { try await repo.insert(capture(i)) }
        let items = try await repo.recentItems()
        #expect(items.count == 200)
        #expect(items.last?.createdAt == Date(timeIntervalSince1970: 5))
    }

    @Test func diskPruningAndClearSurviveReopening() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CopyShelfTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        let location = StoreLocation(applicationSupport: base)
        let policy = RetentionPolicy(unpinnedLimit: 2)
        var pinnedID = UUID()
        do {
            let repo = try HistoryStore.openDisk(location: location, policy: policy)
            let pin = try await repo.insert(capture(0)); pinnedID = pin.id
            try await repo.setPinned(true, id: pin.id)
            for i in 1...4 { try await repo.insert(capture(i)) }
        }
        do {
            let repo = try HistoryStore.openDisk(location: location, policy: policy)
            #expect(try await repo.recentItems().count == 3)
            try await repo.clear(.unpinned)
        }
        do {
            let repo = try HistoryStore.openDisk(location: location, policy: policy)
            #expect(try await repo.recentItems().map(\.id) == [pinnedID])
            try await repo.clear(.all)
        }
        do {
            let repo = try HistoryStore.openDisk(location: location, policy: policy)
            #expect(try await repo.recentItems().isEmpty)
            try await repo.clear(.all)
            try await repo.insert(capture(5))
            try await repo.clear(.unpinned)
            #expect(try await repo.recentItems().isEmpty)
        }
    }
}
