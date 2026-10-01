//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import XCTest
@testable import Scrabbdict

@MainActor
final class AnalyticsConsentFeatureTests: XCTestCase {
    func testAllowStoresAndAppliesConsentThenDismisses() async {
        await assertDecision(.granted, action: .allowButtonTapped)
    }

    func testDenyStoresAndAppliesConsentThenDismisses() async {
        await assertDecision(.denied, action: .denyButtonTapped)
    }

    private func assertDecision(
        _ consent: AnalyticsConsent,
        action: AnalyticsConsentFeature.Action.ViewAction
    ) async {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: AnalyticsConsentFeature.State()) {
            AnalyticsConsentFeature()
        } withDependencies: {
            $0.analyticsConsentStorage.setCurrent = { consent in
                events.withValue { $0.append("store.\(consent)") }
            }
            $0.analyticsClient.applyConsent = { consent in
                events.withValue { $0.append("apply.\(consent)") }
            }
            $0.dismiss = .init {
                events.withValue { $0.append("dismiss") }
            }
        }

        await store.send(.view(action))
        await store.receive(.delegate(.decided(consent)))
        XCTAssertEqual(events.value, ["store.\(consent)", "apply.\(consent)", "dismiss"])
    }
}
