import Foundation

/// A single main-actor poller. Start establishes a baseline without reading existing content.
@MainActor
public final class TextCapture {
    public static let interval: TimeInterval = 0.25
    public static let maximumUTF8Bytes = 1_048_576
    private let pasteboard: any PasteboardReading
    private let sources: any SourceAppProviding
    private let clock: any CaptureClock
    private let repository: any HistoryRepository
    private let onCaptured: @MainActor () -> Void
    private let isPaused: @MainActor () -> Bool
    private let excludedBundleIDs: @MainActor () -> Set<String>
    private static let ignoredTypes: Set<String> = [
        "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
        "de.petermaurer.TransientPasteboardType", "com.typeit4me.clipping",
        "Pasteboard generator type", "com.agilebits.onepassword"
    ]
    private var lastCount: Int?
    private var suppressedCounts: Set<Int> = []
    private var polling = false
    private var active = false
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private var generation = 0

    public init(pasteboard: any PasteboardReading, sources: any SourceAppProviding,
                clock: any CaptureClock, repository: any HistoryRepository,
                isPaused: @escaping @MainActor () -> Bool = { false },
                excludedBundleIDs: @escaping @MainActor () -> Set<String> = { [] },
                onCaptured: @escaping @MainActor () -> Void = {}) {
        self.pasteboard = pasteboard
        self.sources = sources
        self.clock = clock
        self.repository = repository
        self.isPaused = isPaused
        self.excludedBundleIDs = excludedBundleIDs
        self.onCaptured = onCaptured
    }

    public func start() { generation += 1; active = true; lastCount = pasteboard.changeCount }
    private func stop() { generation += 1; active = false; lastCount = nil; suppressedCounts.removeAll() }

    /// Pause completes only after an already-dispatched save has finished.
    public func stopAndWait() async {
        stop()
        guard polling else { return }
        await withCheckedContinuation { drainWaiters.append($0) }
    }

    /// Register the count returned by a successful own write before the next poll.
    public func suppressOwnWrite(changeCount: Int) { suppressedCounts.insert(changeCount) }

    /// A wake triggers a normal poll, preserving changes observed while asleep.
    public func poll() async throws {
        guard active, !polling else { return }
        if isPaused() { lastCount = nil; suppressedCounts.removeAll(); return }
        guard let previous = lastCount else { lastCount = pasteboard.changeCount; return }
        let count = pasteboard.changeCount
        guard count != previous else { return }
        polling = true
        let currentGeneration = generation
        defer {
            polling = false
            let waiters = drainWaiters
            drainWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        if suppressedCounts.remove(count) != nil {
            lastCount = count
            suppressedCounts.removeAll()
            return
        }
        suppressedCounts.removeAll()
        let types = pasteboard.availableTypes()
        if types.contains("public.file-url") || !types.isDisjoint(with: Self.ignoredTypes) {
            lastCount = count
            return
        }
        let source = sources.frontmostSource()
        if let id = source.bundleID, id == "com.sangam.copyshelf" || excludedBundleIDs().contains(id) {
            lastCount = count
            return
        }
        guard let text = try pasteboard.readText(), !text.isEmpty,
              text.utf8.count <= Self.maximumUTF8Bytes else {
            lastCount = count
            return
        }
        guard pasteboard.changeCount == count else { return }
        let capturedAt = clock.now()
        let newest = try await repository.recentItems().first
        guard generation == currentGeneration, !isPaused() else { return }
        if newest.map({ !$0.text.utf8.elementsEqual(text.utf8) || $0.source.bundleID != source.bundleID }) ?? true {
            // Keep capture ordering deterministic if the wall clock ties or moves backwards.
            let orderedTime = newest.map { max(capturedAt, $0.createdAt.addingTimeInterval(0.001)) } ?? capturedAt
            try await repository.insert(CapturedText(text: text, source: source, capturedAt: orderedTime))
            onCaptured()
        }
        if generation == currentGeneration { lastCount = count }
    }
}
