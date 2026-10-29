import Foundation
import Testing
@testable import CopyShelfCore

@MainActor
struct AppSettingsTests {
    private func withDefaults(_ check: (UserDefaults) throws -> Void) rethrows {
        let name = "CopyShelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try check(defaults)
    }

    @Test func freshSettingsArePaused() {
        withDefaults { defaults in
            #expect(AppSettings(defaults: defaults).capturePaused)
        }
    }

    @Test func preferenceSurvivesNewSettingsInstance() {
        withDefaults { defaults in
            AppSettings(defaults: defaults).capturePaused = false
            #expect(!AppSettings(defaults: defaults).capturePaused)
        }
    }

    @Test func consentDefaultsToDeniedAndPersistsOnlyWhenGranted() {
        withDefaults { defaults in
            #expect(!AppSettings(defaults: defaults).captureConsentGranted)
            AppSettings(defaults: defaults).captureConsentGranted = true
            #expect(AppSettings(defaults: defaults).captureConsentGranted)
            AppSettings(defaults: defaults).captureConsentGranted = false
            #expect(!AppSettings(defaults: defaults).captureConsentGranted)
        }
    }

    @Test func togglingTwiceReturnsToPaused() {
        withDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.toggleCapturePaused()
            #expect(!settings.capturePaused)
            settings.toggleCapturePaused()
            #expect(settings.capturePaused)
            #expect(AppSettings(defaults: defaults).capturePaused)
        }
    }
}

@MainActor
struct RetentionSettingsTests {
    @Test func limitSettingsAndPolicy() {
        let name = "CopyShelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(AppSettings(defaults: defaults).unpinnedHistoryLimit == 200)
        AppSettings(defaults: defaults).unpinnedHistoryLimit = 123
        #expect(AppSettings(defaults: defaults).unpinnedHistoryLimit == 123)
        for value: Any in [0, -5, "42", true, 1.5] {
            defaults.set(value, forKey: "unpinnedHistoryLimit")
            #expect(AppSettings(defaults: defaults).unpinnedHistoryLimit == 200)
        }
        defaults.set(5000, forKey: "unpinnedHistoryLimit")
        #expect(AppSettings(defaults: defaults).unpinnedHistoryLimit == 1000)
        #expect(RetentionPolicy(unpinnedLimit: 0).unpinnedLimit == 1)
        #expect(RetentionPolicy(unpinnedLimit: 1001).unpinnedLimit == 1000)
    }
    @Test func orderingAndSummary() {
        let date = Date(timeIntervalSince1970: 1)
        let first = HistoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, createdAt: date, text: "a", source: SourceApp(), isPinned: true)
        let second = HistoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, createdAt: date, text: "b", source: SourceApp())
        let newer = HistoryItem(id: UUID(), createdAt: date.addingTimeInterval(1), text: "c", source: SourceApp())
        #expect([second, first, newer].sorted(by: HistoryOrdering.precedes) == [newer, first, second])
        let summary = HistorySummary(items: [first, second, newer], policy: RetentionPolicy(unpinnedLimit: 2))
        #expect(summary.total == 3 && summary.pinned == 1 && summary.unpinned == 2 && summary.limit == 2)
    }
}
