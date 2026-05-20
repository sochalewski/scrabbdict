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
        var selectedLanguage: Language = .englishUS
    }

    enum Action: Sendable, Equatable, ViewAction {
        case view(ViewAction)
        case delegate(DelegateAction)

        enum ViewAction: Sendable, Equatable {
            case loaded
            case cancelButtonTapped
            case languageSelected(Language)
            case saveButtonTapped
        }

        enum DelegateAction: Sendable, Equatable {
            case languageUpdated
        }
    }

    @Dependency(\.languageStorage) var languageStorage
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .loaded:
                    state.selectedLanguage = languageStorage.current()
                    return .none
                case .cancelButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .languageSelected(language):
                    state.selectedLanguage = language
                    return .none
                case .saveButtonTapped:
                    let currentLanguage = languageStorage.current()
                    languageStorage.setCurrent(state.selectedLanguage)
                    return .run { [selectedLanguage = state.selectedLanguage] send in
                        if selectedLanguage != currentLanguage {
                            analytics.logLanguageChanged(selectedLanguage)
                            await send(.delegate(.languageUpdated))
                        }
                        await dismiss()
                    }
                }
            case .delegate:
                return .none
            }
        }
    }
}
