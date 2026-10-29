import Foundation
import Observation

public struct PasteTarget: Sendable, Equatable {
    public let pid: Int32
    public let launchDate: Date?
    public let focusToken: UUID
    public init(pid: Int32, launchDate: Date?, focusToken: UUID) {
        self.pid = pid; self.launchDate = launchDate; self.focusToken = focusToken
    }
}

@MainActor public protocol PasteEnvironment: AnyObject {
    func isAuthorized() -> Bool
    func isTrusted() -> Bool
    func targetExists(_ target: PasteTarget) -> Bool
    func closePanel()
    func activate(_ target: PasteTarget) async -> Bool
    func focusMatches(_ target: PasteTarget) -> Bool
    func sendPasteShortcut(to target: PasteTarget) throws
}

public enum PasteOutcome: Equatable, Sendable {
    case noSelection, consentRequired, accessibilityRequired, targetUnavailable
    case busy, cancelled, copyFailed, activationFailed, permissionRevoked, targetLost, focusChanged, eventFailed, shortcutSent
}

@MainActor @Observable
public final class PasteCoordinator {
    private let environment: any PasteEnvironment
    private let copy: CopyCoordinator
    private var generation = 0
    private var running = false
    public private(set) var outcome: PasteOutcome?

    public init(environment: any PasteEnvironment, copy: CopyCoordinator) {
        self.environment = environment; self.copy = copy
    }

    public func cancel() { generation += 1 }
    public func clearOutcome() { outcome = nil }

    public func paste(_ item: HistoryItem?, to target: PasteTarget?) async {
        guard !running else { outcome = .busy; return }
        guard let item else { outcome = .noSelection; return }
        guard environment.isAuthorized() else { outcome = .consentRequired; return }
        guard environment.isTrusted() else { outcome = .accessibilityRequired; return }
        guard let target, environment.targetExists(target) else { outcome = .targetUnavailable; return }
        running = true
        generation += 1
        let request = generation
        defer { running = false }
        copy.copy(item)
        guard copy.outcome == .copied else { outcome = .copyFailed; return }
        environment.closePanel()
        guard await environment.activate(target) else { outcome = .activationFailed; return }
        guard request == generation else { outcome = .cancelled; return }
        guard environment.isAuthorized(), environment.isTrusted() else { outcome = .permissionRevoked; return }
        guard environment.targetExists(target) else { outcome = .targetLost; return }
        guard environment.focusMatches(target) else { outcome = .focusChanged; return }
        do { try environment.sendPasteShortcut(to: target); outcome = .shortcutSent }
        catch { outcome = .eventFailed }
    }
}
