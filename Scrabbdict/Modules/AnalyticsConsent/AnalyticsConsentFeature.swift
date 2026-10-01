//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AnalyticsConsentFeature {
    @ObservableState
    struct State: Hashable, Sendable {}

    enum Action: Hashable, Sendable, ViewAction {
        case view(ViewAction)
        case delegate(DelegateAction)

        enum ViewAction: Hashable, Sendable {
            case allowButtonTapped
            case denyButtonTapped
        }

        enum DelegateAction: Hashable, Sendable {
            case decided(AnalyticsConsent)
        }
    }

    @Dependency(\.analyticsConsentStorage) var consentStorage
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .view(.allowButtonTapped):
                decide(.granted)
            case .view(.denyButtonTapped):
                decide(.denied)
            case .delegate:
                .none
            }
        }
    }

    private func decide(_ consent: AnalyticsConsent) -> Effect<Action> {
        consentStorage.setCurrent(consent)
        analytics.applyConsent(consent)
        return .run { send in
            await send(.delegate(.decided(consent)))
            await dismiss()
        }
    }
}
