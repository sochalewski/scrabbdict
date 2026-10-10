//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import FirebaseAnalytics
import Foundation

struct AnalyticsClient: Sendable {
    var applyConsent: @Sendable (AnalyticsConsent) -> Void
    var logLanguageChanged: @Sendable (Language) -> Void
    var logModeChanged: @Sendable (SearchMode) -> Void
    var logPrivacyPolicyOpened: @Sendable () -> Void
    var logRegexSearch: @Sendable (Language) -> Void
    var logSettingsOpened: @Sendable () -> Void
    var logTilesSearch: @Sendable (Language) -> Void
    var logWordChecked: @Sendable (Language, Bool) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = Self(
        applyConsent: { consent in
            let isGranted = consent == .granted
            Analytics.setConsent([
                .analyticsStorage: isGranted ? .granted : .denied,
                .adStorage: .denied,
                .adUserData: .denied,
                .adPersonalization: .denied
            ])
            Analytics.setAnalyticsCollectionEnabled(isGranted)
            if !isGranted {
                Analytics.resetAnalyticsData()
            }
        },
        logLanguageChanged: { language in
            logEvent("language_changed", parameters: ["language": language.rawValue])
        },
        logModeChanged: { searchMode in
            logEvent("mode_changed", parameters: ["mode": searchMode.name])
        },
        logPrivacyPolicyOpened: {
            logEvent("privacy_policy_opened")
        },
        logRegexSearch: { language in
            logEvent("regex", parameters: ["language": language.rawValue])
        },
        logSettingsOpened: {
            logEvent("settings_opened")
        },
        logTilesSearch: { language in
            logEvent("tiles", parameters: ["language": language.rawValue])
        },
        logWordChecked: { language, exists in
            logEvent("word_check", parameters: ["language": language.rawValue, "exists": exists ? "yes" : "no"])
        }
    )

    static let testValue = Self(
        applyConsent: unimplemented("\(Self.self).applyConsent"),
        logLanguageChanged: unimplemented("\(Self.self).logLanguageChanged"),
        logModeChanged: unimplemented("\(Self.self).logModeChanged"),
        logPrivacyPolicyOpened: unimplemented("\(Self.self).logPrivacyPolicyOpened"),
        logRegexSearch: unimplemented("\(Self.self).logRegexSearch"),
        logSettingsOpened: unimplemented("\(Self.self).logSettingsOpened"),
        logTilesSearch: unimplemented("\(Self.self).logTilesSearch"),
        logWordChecked: unimplemented("\(Self.self).logWordChecked")
    )

    static let previewValue = Self(
        applyConsent: { _ in },
        logLanguageChanged: { _ in },
        logModeChanged: { _ in },
        logPrivacyPolicyOpened: {},
        logRegexSearch: { _ in },
        logSettingsOpened: {},
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

// Guards against Firebase's persisted collection state diverging from the stored consent.
private func logEvent(_ name: String, parameters: [String: Any]? = nil) {
    @Dependency(\.analyticsConsentStorage) var consentStorage

    guard consentStorage.current() == .granted else { return }
    Analytics.logEvent(name, parameters: parameters)
}
