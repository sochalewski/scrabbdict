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
final class SettingsSnapshotTests: XCTestCase {
    func testEnglishGBSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .englishGB)
    }

    func testEnglishUSSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .englishUS)
    }

    func testFrenchSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .french)
    }

    func testPolishSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .polish)
    }
}

@MainActor
private func assertSettingsScreenSnapshots(
    selectedLanguage: Language,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    assertScreenSnapshots(
        drawHierarchyInKeyWindow: true,
        file: file,
        testName: testName,
        line: line
    ) { deviceConfig, colorScheme in
        fixedScreen(
            SettingsView(
                store: Store(
                    initialState: SettingsFeature.State(selectedLanguage: selectedLanguage),
                    reducer: {}
                )
            ),
            deviceConfig: deviceConfig,
            colorScheme: colorScheme
        )
    }
}
