import CopyShelfCore
import Foundation
import Testing

/// CS-04 must instantiate this same contract with a fresh SwiftData repository
/// factory (temporary own-store fixtures). Assertions bind both implementations.
struct HistoryRepositoryContract<Repository: HistoryRepository> {
    let makeRepository: @Sendable () async throws -> Repository

    private func capture(_ text: String, time: TimeInterval) -> CapturedText {
        CapturedText(text: text, source: SourceApp(bundleID: "test.synthetic.editor", name: "Fixture Editor"),
                     capturedAt: Date(timeIntervalSince1970: time))
    }

    func insertAndOrder() async throws {
        let repository = try await makeRepository()
        #expect(try await repository.recentItems().isEmpty)
        let newer = try await repository.insert(capture("  héllo\n\tworld 👋  ", time: 2))
        let older = try await repository.insert(capture("older", time: 1))
        let items = try await repository.recentItems()
        #expect(items == [newer, older])
        #expect(newer.id != older.id)
        #expect(Array(items[0].text.utf8) == Array("  héllo\n\tworld 👋  ".utf8))
        #expect(items[0].createdAt == Date(timeIntervalSince1970: 2))
        #expect(items[0].source == capture("", time: 0).source)
        #expect(items.allSatisfy { $0.kind == .text && !$0.isPinned })
    }

    func pinOnlyTarget() async throws {
        let repository = try await makeRepository()
        let first = try await repository.insert(capture("first", time: 1))
        let second = try await repository.insert(capture("second", time: 2))
        try await repository.setPinned(true, id: first.id)
        let items = try await repository.recentItems()
        #expect(items.first { $0.id == first.id }?.isPinned == true)
        #expect(items.first { $0.id == second.id } == second)
        try await repository.setPinned(false, id: first.id)
        #expect(try await repository.recentItems() == [second, first])
    }

    func clearPreservesPinsOnlyWhenRequested() async throws {
        let repository = try await makeRepository()
        let pin = try await repository.insert(capture("pin", time: 1))
        try await repository.insert(capture("ordinary", time: 2))
        try await repository.setPinned(true, id: pin.id)
        try await repository.clear(.unpinned)
        let remaining = try await repository.recentItems()
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == pin.id)
        #expect(remaining.first?.isPinned == true)
        try await repository.clear(.all)
        #expect(try await repository.recentItems().isEmpty)
    }

    func deletionAndUnknownIDs() async throws {
        let repository = try await makeRepository()
        let item = try await repository.insert(capture("keep", time: 1))
        try await repository.delete(id: UUID())
        try await repository.setPinned(true, id: UUID())
        #expect(try await repository.recentItems() == [item])
        try await repository.delete(id: item.id)
        try await repository.delete(id: item.id)
        #expect(try await repository.recentItems().isEmpty)
    }

    func equalTimestampsHaveStableOrdering() async throws {
        let repository = try await makeRepository()
        let first = try await repository.insert(capture("first", time: 1))
        let second = try await repository.insert(capture("second", time: 1))
        let expected = [first, second].sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(try await repository.recentItems() == expected)
    }
}

struct HistoryRepositoryContractTests {
    private var contract: HistoryRepositoryContract<InMemoryHistoryRepository> {
        HistoryRepositoryContract(makeRepository: { InMemoryHistoryRepository() })
    }

    @Test func insertAndOrder() async throws { try await contract.insertAndOrder() }
    @Test func pinOnlyTarget() async throws { try await contract.pinOnlyTarget() }
    @Test func clearScopes() async throws { try await contract.clearPreservesPinsOnlyWhenRequested() }
    @Test func deletionAndUnknownIDs() async throws { try await contract.deletionAndUnknownIDs() }
    @Test func equalTimestamps() async throws { try await contract.equalTimestampsHaveStableOrdering() }
}
