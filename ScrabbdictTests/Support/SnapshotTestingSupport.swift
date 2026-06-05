//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SnapshotTesting
import SwiftUI

extension ViewImageConfig {
    static let iPhone17Pro = ViewImageConfig(
        safeArea: .init(top: 62, left: 0, bottom: 34, right: 0),
        size: .init(width: 402, height: 874),
        traits: UITraitCollection { traits in
            traits.userInterfaceIdiom = .phone
            traits.horizontalSizeClass = .compact
            traits.verticalSizeClass = .regular
            traits.displayScale = 1
        }
    )

    static let iPad13 = ViewImageConfig(
        safeArea: .init(top: 24, left: 0, bottom: 20, right: 0),
        size: .init(width: 1032, height: 1376),
        traits: UITraitCollection { traits in
            traits.userInterfaceIdiom = .pad
            traits.horizontalSizeClass = .regular
            traits.verticalSizeClass = .regular
            traits.displayScale = 1
        }
    )
}

@MainActor
func assertScreenSnapshots(
    deviceConfigs: [(ViewImageConfig, String)] = [
        (.iPhone17Pro, ""),
        (.iPad13, "pad.")
    ],
    locales: [Locale] = [
        Locale(identifier: "en_US"),
        Locale(identifier: "pl_PL"),
        Locale(identifier: "fr_FR")
    ],
    drawHierarchyInKeyWindow: Bool = false,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line,
    _ makeView: (ViewImageConfig, ColorScheme, Locale) -> some View
) {
    for locale in locales {
        let localeSnapshotName = locale.identifier
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "@", with: "-")

        for (deviceConfig, namePrefix) in deviceConfigs {
            for (colorScheme, name) in [(ColorScheme.light, "light"), (.dark, "dark")] {
                assertSnapshot(
                    of: makeView(deviceConfig, colorScheme, locale)
                        .frame(
                            width: deviceConfig.size?.width,
                            height: deviceConfig.size?.height
                        ),
                    as: .image(
                        drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
                        precision: 0.999,
                        layout: .device(config: deviceConfig),
                        traits: deviceConfig.traits.modifyingTraits {
                            $0.userInterfaceStyle = colorScheme == .light ? .light : .dark
                        }
                    ),
                    named: "\(localeSnapshotName).\(namePrefix)\(name)",
                    file: file,
                    testName: testName,
                    line: line
                )
            }
        }
    }
}

@MainActor
func fixedScreen(
    _ content: some View,
    deviceConfig: ViewImageConfig = .iPhone17Pro,
    colorScheme: ColorScheme,
    locale: Locale
) -> some View {
    content
        .environment(\.colorScheme, colorScheme)
        .environment(\.locale, locale)
        .frame(
            width: deviceConfig.size?.width,
            height: deviceConfig.size?.height
        )
}
