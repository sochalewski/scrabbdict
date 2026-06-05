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
final class ScrabbdictSnapshotTests: XCTestCase {
    func testValidResult() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quiz",
                result: .valid(points: 22)
            )
        )
    }

    func testValidResultWithRackWordsButton() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quiz",
                result: .valid(points: 22),
                showsRackWordsButton: true
            )
        )
    }

    func testInvalidResult() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quizes",
                result: .invalid
            )
        )
    }

    func testInvalidResultWithRackWordsButtonResult() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quizes",
                result: .invalid,
                showsRackWordsButton: true
            )
        )
    }

    func testWordMatches() {
        assertAppScreenSnapshots(
            state: .init(
                query: "retains",
                words: [
                    Word(string: "nastier", points: 7),
                    Word(string: "retains", points: 7),
                    Word(string: "stainer", points: 7),
                    Word(string: "retina", points: 6),
                    Word(string: "retain", points: 6),
                    Word(string: "sinter", points: 6)
                ]
            )
        )
    }

    func testSearchModePickerExpanded() {
        assertAppScreenSnapshots(
            state: .init(
                searchMode: .auto,
                isSearchModePickerExpanded: true
            )
        )
    }

    func testResultSkeleton() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quiz",
                search: .result(showsRackWordsButton: false)
            )
        )
    }

    func testResultSkeletonWithRackWordsButton() {
        assertAppScreenSnapshots(
            state: .init(
                query: "quiz",
                search: .result(showsRackWordsButton: true)
            )
        )
    }

    func testWordsSkeleton() {
        assertAppScreenSnapshots(
            state: .init(
                query: "retains",
                search: .words
            )
        )
    }

    func testEmptyPatternResult() {
        assertAppScreenSnapshots(
            state: .init(
                query: "zz???",
                emptyResult: .pattern
            )
        )
    }

    func testEmptyRackResult() {
        assertAppScreenSnapshots(
            state: .init(
                query: "zzzzz",
                emptyResult: .rack
            )
        )
    }
}

@MainActor
private func assertAppScreenSnapshots(
    state: ScrabbdictFeature.State,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    assertScreenSnapshots(
        drawHierarchyInKeyWindow: true,
        file: file,
        testName: testName,
        line: line
    ) { deviceConfig, colorScheme, locale in
        fixedScreen(
            ScrabbdictView(
                store: Store(
                    initialState: state,
                    reducer: {}
                )
            ),
            deviceConfig: deviceConfig,
            colorScheme: colorScheme,
            locale: locale
        )
    }
}
