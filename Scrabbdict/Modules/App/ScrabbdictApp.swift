//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI

@main
struct ScrabbdictApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ScrabbdictView(
                store: Store(initialState: ScrabbdictFeature.State()) {
                    ScrabbdictFeature()
                }
            )
            #if DEBUG && targetEnvironment(simulator)
            .dynamicTypeSizeOverlay()
            #endif
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
    private extension View {
        func dynamicTypeSizeOverlay() -> some View {
            modifier(DynamicTypeSizeOverlayModifier())
        }
    }

    private struct DynamicTypeSizeOverlayModifier: ViewModifier {
        @Environment(\.dynamicTypeSize) var dynamicTypeSize

        func body(content: Content) -> some View {
            content
                .overlay(alignment: .topLeading) {
                    Text(verbatim: .init(describing: dynamicTypeSize))
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.72), in: .capsule)
                        .padding(12)
                        .opacity(dynamicTypeSize == .large ? 0 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
    }
#endif
