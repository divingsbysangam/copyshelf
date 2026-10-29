import Foundation
import CoreFoundation
import Observation

@MainActor
@Observable
public final class AppSettings {
    private let defaults: UserDefaults

    public var capturePaused: Bool {
        didSet { defaults.set(capturePaused, forKey: "capturePaused") }
    }

    public var captureConsentGranted: Bool {
        didSet { defaults.set(captureConsentGranted, forKey: "captureConsentGranted") }
    }
    public var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: "excludedBundleIDs") }
    }

    public var unpinnedHistoryLimit: Int {
        didSet {
            let normalized = Self.readLimit(unpinnedHistoryLimit)
            if normalized != unpinnedHistoryLimit { unpinnedHistoryLimit = normalized }
            defaults.set(normalized, forKey: "unpinnedHistoryLimit")
        }
    }

    private static func readLimit(_ value: Any?) -> Int {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              CFNumberIsFloatType(number as CFNumber) == false,
              number.int64Value > 0 else { return RetentionPolicy.defaultLimit }
        return min(number.intValue, RetentionPolicy.maximumLimit)
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.captureConsentGranted = defaults.object(forKey: "captureConsentGranted") as? Bool ?? false
        self.excludedBundleIDs = defaults.stringArray(forKey: "excludedBundleIDs") ?? []
        self.unpinnedHistoryLimit = Self.readLimit(defaults.object(forKey: "unpinnedHistoryLimit"))
        self.capturePaused = defaults.object(forKey: "capturePaused") as? Bool ?? true
    }

    public func toggleCapturePaused() {
        capturePaused.toggle()
    }
}
