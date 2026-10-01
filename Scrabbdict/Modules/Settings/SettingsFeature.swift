//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Hashable, Sendable {
        var selectedLanguage: Language = .englishNWL
        var isAnalyticsEnabled = false
    }

    enum Action: Hashable, Sendable, ViewAction {
        case view(ViewAction)
        case delegate(DelegateAction)

        enum ViewAction: Hashable, Sendable {
            case loaded
            case analyticsToggled(Bool)
            case closeButtonTapped
            case languageSelected(Language)
        }

        enum DelegateAction: Hashable, Sendable {
            case languageUpdated
        }
    }

    @Dependency(\.languageStorage) var languageStorage
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.analyticsConsentStorage) var analyticsConsentStorage
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .loaded:
                    state.selectedLanguage = languageStorage.current()
                    state.isAnalyticsEnabled = analyticsConsentStorage.current() == .granted
                    return .none
                case let .analyticsToggled(isEnabled):
                    state.isAnalyticsEnabled = isEnabled
                    let consent: AnalyticsConsent = isEnabled ? .granted : .denied
                    analyticsConsentStorage.setCurrent(consent)
                    analytics.applyConsent(consent)
                    return .none
                case .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .languageSelected(language):
                    guard language != state.selectedLanguage else { return .none }
                    state.selectedLanguage = language
                    languageStorage.setCurrent(language)
                    analytics.logLanguageChanged(language)
                    return .send(.delegate(.languageUpdated))
                }
            case .delegate:
                return .none
            }
        }
    }
}
