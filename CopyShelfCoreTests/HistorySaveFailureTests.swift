import Foundation
import SwiftData
import Testing
@testable import CopyShelfCore

private final class SaveSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var failing = false
    func set(_ value: Bool) { lock.lock(); defer { lock.unlock() }; failing = value }
    func save(_ context: ModelContext) throws {
        lock.lock(); let shouldFail = failing; lock.unlock()
        if shouldFail { throw NSError(domain: "CopyShelfTests", code: 42) }
        try context.save()
    }
}

struct HistorySaveFailureTests {
    @Test func failedFirstInsertLeavesEmptyStore() async throws {
        let gate = SaveSwitch()
        let repo = SwiftDataHistoryRepository(container: try StoreLocation.inMemoryContainer(), saveHook: { try gate.save($0) })
        gate.set(true)
        do {
            try await repo.insert(CapturedText(text: "fixture", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: 0)))
            Issue.record("Expected a save failure")
        } catch {
            #expect(error as? HistoryRepositoryError == .saveFailed(domain: "CopyShelfTests", code: 42))
        }
        #expect(try await repo.recentItems().isEmpty)
    }

    @Test func failedMutationsRollbackAndRecoveryWorks() async throws {
        let gate = SaveSwitch()
        let repo = SwiftDataHistoryRepository(container: try StoreLocation.inMemoryContainer(), policy: RetentionPolicy(unpinnedLimit: 2), saveHook: { try gate.save($0) })
        func capture(_ i: Int) -> CapturedText { CapturedText(text: "synthetic secret \(i)", source: SourceApp(), capturedAt: Date(timeIntervalSince1970: Double(i))) }
        let pin = try await repo.insert(capture(0))
        try await repo.setPinned(true, id: pin.id)
        let first = try await repo.insert(capture(1))
        try await repo.insert(capture(2))
        let before = try await repo.recentItems()
        gate.set(true)
        let actions: [() async throws -> Void] = [
            { _ = try await repo.insert(capture(3)) },
            { try await repo.setPinned(true, id: first.id) },
            { try await repo.delete(id: first.id) },
            { try await repo.clear(.unpinned) },
            { try await repo.clear(.all) }
        ]
        for action in actions {
            do { try await action(); Issue.record("Expected a save failure") }
            catch {
                #expect(error as? HistoryRepositoryError == .saveFailed(domain: "CopyShelfTests", code: 42))
                #expect(!String(describing: error).contains("synthetic secret"))
            }
            #expect(try await repo.recentItems() == before)
        }
        gate.set(false)
        let recovered = try await repo.insert(capture(4))
        let after = try await repo.recentItems()
        #expect(after.contains { $0.id == recovered.id })
        #expect(after.count == 3 && !after.contains { $0.id == first.id })
    }
}
