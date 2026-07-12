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
    func testEnglishCSWSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .englishCSW)
    }

    func testEnglishNWLSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .englishNWL)
    }

    func testEnglishWOWSelected() {
        assertSettingsScreenSnapshots(selectedLanguage: .englishWOW)
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
    assert(
        SettingsView(
            store: Store(
                initialState: SettingsFeature.State(selectedLanguage: selectedLanguage),
                reducer: {}
            )
        ),
        file: file,
        testName: testName,
        line: line
    )
}
