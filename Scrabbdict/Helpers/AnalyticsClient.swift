//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import FirebaseAnalytics
import Foundation

struct AnalyticsClient: Sendable {
    var logLanguageChanged: @Sendable (Language) -> Void
    var logModeChanged: @Sendable (SearchMode) -> Void
    var logRegexSearch: @Sendable (Language) -> Void
    var logTilesSearch: @Sendable (Language) -> Void
    var logWordChecked: @Sendable (Language, Bool) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = Self(
        logLanguageChanged: { language in
            Analytics.logEvent("language_changed", parameters: ["language": language.rawValue])
        },
        logModeChanged: { searchMode in
            Analytics.logEvent("mode_changed", parameters: ["mode": searchMode.name])
        },
        logRegexSearch: { language in
            Analytics.logEvent("regex", parameters: ["language": language.rawValue])
        },
        logTilesSearch: { language in
            Analytics.logEvent("tiles", parameters: ["language": language.rawValue])
        },
        logWordChecked: { language, exists in
            Analytics.logEvent("word_check", parameters: ["language": language.rawValue, "exists": exists ? "yes" : "no"])
        }
    )

    static let testValue = Self(
        logLanguageChanged: unimplemented("\(Self.self).logLanguageChanged"),
        logModeChanged: unimplemented("\(Self.self).logModeChanged"),
        logRegexSearch: unimplemented("\(Self.self).logRegexSearch"),
        logTilesSearch: unimplemented("\(Self.self).logTilesSearch"),
        logWordChecked: unimplemented("\(Self.self).logWordChecked")
    )

    static let previewValue = Self(
        logLanguageChanged: { _ in },
        logModeChanged: { _ in },
        logRegexSearch: { _ in },
        logTilesSearch: { _ in },
        logWordChecked: { _, _ in }
    )
}

extension DependencyValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
