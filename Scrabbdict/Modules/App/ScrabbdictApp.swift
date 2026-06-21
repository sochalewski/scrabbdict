//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import StoreKit
import SwiftUI

@main
struct ScrabbdictApp: App {
    #if !DEBUG && !targetEnvironment(simulator)
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ScrabbdictRootView()
            #if DEBUG && targetEnvironment(simulator)
                .dynamicTypeSizeOverlay()
            #endif
        }
    }
}

private struct ScrabbdictRootView: View {
    @Environment(\.requestReview) var requestReview

    var body: some View {
        ScrabbdictView(
            store: Store(initialState: ScrabbdictFeature.State()) {
                ScrabbdictFeature()
            } withDependencies: {
                $0.appReviewClient.requestReview = {
                    requestReview()
                }
            }
        )
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.72), in: .capsule)
                        .padding(12)
                        .opacity(dynamicTypeSize == .large ? 0 : 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        }
    }
#endif
