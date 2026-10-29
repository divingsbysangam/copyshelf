import Foundation
import Observation

public enum HistoryFilter: Hashable, Sendable {
    case all
    case pinned
    case source(String?)
}

public struct HistorySource: Identifiable, Hashable, Sendable {
    public let bundleID: String?
    public let name: String
    public var id: String { bundleID ?? "" }
}

@MainActor @Observable
public final class HistoryBrowser {
    public var query = "" { didSet { reconcileSelection() } }
    public var filter: HistoryFilter = .all { didSet { reconcileSelection() } }
    public var selectedID: UUID?
    public private(set) var items: [HistoryItem] = []
    public private(set) var isLoading = false
    public private(set) var hasError = false
    private let repository: any HistoryRepository
    private var refreshVersion = 0

    public init(repository: any HistoryRepository) { self.repository = repository }

    public var sources: [HistorySource] {
        var seen: Set<String> = []
        var sources: [HistorySource] = []
        for item in items {
            let key = item.source.bundleID ?? ""
            if seen.insert(key).inserted {
                sources.append(HistorySource(bundleID: item.source.bundleID,
                                             name: item.source.bundleID == nil ? "Unknown" : item.source.displayName))
            }
        }
        return sources.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var visibleItems: [HistoryItem] {
        items.filter { item in
            let filterMatches: Bool
            switch filter {
            case .all: filterMatches = true
            case .pinned: filterMatches = item.isPinned
            case .source(let id): filterMatches = item.source.bundleID == id
            }
            return filterMatches && (query.isEmpty || item.text.localizedCaseInsensitiveContains(query))
        }
    }

    public var selectedItem: HistoryItem? { visibleItems.first { $0.id == selectedID } }

    public func selectNext(_ direction: Int) {
        let ids = visibleItems.map(\.id)
        guard !ids.isEmpty else { selectedID = nil; return }
        guard let selectedID, let index = ids.firstIndex(of: selectedID) else {
            self.selectedID = direction < 0 ? ids.last : ids.first
            return
        }
        self.selectedID = ids[min(max(index + (direction < 0 ? -1 : 1), 0), ids.count - 1)]
    }

    private func reconcileSelection() {
        guard let selectedID, !visibleItems.contains(where: { $0.id == selectedID }) else { return }
        self.selectedID = visibleItems.first?.id
    }

    public func refresh() async {
        refreshVersion += 1
        let version = refreshVersion
        isLoading = true
        do {
            let fetched = try await repository.recentItems()
            guard version == refreshVersion else { return }
            items = fetched
            reconcileSelection()
            hasError = false
            isLoading = false
        } catch {
            guard version == refreshVersion else { return }
            hasError = true
            isLoading = false
        }
    }

    public func setPinned(_ pinned: Bool, id: UUID) async {
        do { try await repository.setPinned(pinned, id: id); await refresh() }
        catch { hasError = true }
    }

    public func clearAll() async {
        refreshVersion += 1
        isLoading = false
        do { try await repository.clear(.all); await refresh() }
        catch { hasError = true }
    }
}
