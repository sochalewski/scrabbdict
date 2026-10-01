//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI
import XCTest
@testable import Scrabbdict

@MainActor
final class AnalyticsConsentSnapshotTests: XCTestCase {
    func testAnalyticsConsent() {
        assert(
            AnalyticsConsentView(
                store: Store(
                    initialState: AnalyticsConsentFeature.State(),
                    reducer: {}
                )
            )
        )
    }
}
