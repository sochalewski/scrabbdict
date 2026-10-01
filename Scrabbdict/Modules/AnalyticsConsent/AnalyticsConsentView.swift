//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI

@ViewAction(for: AnalyticsConsentFeature.self)
struct AnalyticsConsentView: View {
    let store: StoreOf<AnalyticsConsentFeature>

    @ScaledMetric(relativeTo: .title) var tileSize: CGFloat = 64
    @ScaledMetric(relativeTo: .body) var iconBadgeSize: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 28) {
                    tiles
                    card
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            buttons
        }
        .background {
            ScrabbleTableBackground()
                .ignoresSafeArea()
        }
        .tint(.brandAccent)
    }
}

private extension AnalyticsConsentView {
    var tiles: some View {
        HStack(spacing: tileSize * 0.18) {
            SymbolTile(systemImage: "chart.bar.fill", size: tileSize)
                .rotationEffect(.degrees(-8))
            SymbolTile(systemImage: "hand.raised.fill", size: tileSize)
                .offset(y: -tileSize * 0.12)
            SymbolTile(systemImage: "checkmark.shield.fill", size: tileSize)
                .rotationEffect(.degrees(8))
        }
        .padding(.top, tileSize * 0.12)
        .accessibilityHidden(true)
    }

    var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(.analyticsConsentTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primaryInk)
                    .accessibilityAddTraits(.isHeader)

                Text(.analyticsConsentMessage)
                    .font(.body)
                    .foregroundStyle(.secondaryText)
            }

            infoRow(
                systemImage: "chart.bar.xaxis",
                color: .resultBlue,
                title: .analyticsConsentSharedTitle,
                message: .analyticsConsentSharedMessage
            )

            infoRow(
                systemImage: "eye.slash.fill",
                color: .resultGreen,
                title: .analyticsConsentNeverTitle,
                message: .analyticsConsentNeverMessage
            )

            infoRow(
                systemImage: "wrench.and.screwdriver.fill",
                color: .brandAccent,
                title: .analyticsConsentCrashesTitle,
                message: .analyticsConsentCrashesMessage
            )

            Rectangle()
                .fill(.divider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(.analyticsConsentFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)

                Link(destination: .privacyPolicy) {
                    Text(.privacyPolicyLink)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.elevatedSurface, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .appShadow, radius: 17, x: 0, y: 14)
    }

    var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                denyButton
                allowButton
            }

            VStack(spacing: 12) {
                allowButton
                denyButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    var allowButton: some View {
        Button {
            send(.allowButtonTapped)
        } label: {
            buttonLabel(.analyticsConsentAllow)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    var denyButton: some View {
        Button {
            send(.denyButtonTapped)
        } label: {
            buttonLabel(.analyticsConsentDeny)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    func buttonLabel(_ title: LocalizedStringResource) -> some View {
        // Sizes both labels to the longer title so `ViewThatFits` stacks the buttons before either wraps.
        ZStack {
            Text(.analyticsConsentAllow).hidden()
            Text(.analyticsConsentDeny).hidden()
            Text(title)
        }
        .font(.headline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    func infoRow(
        systemImage: String,
        color: Color,
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: iconBadgeSize, height: iconBadgeSize)
                .background(color.opacity(0.15), in: .rect(cornerRadius: iconBadgeSize * 0.3))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primaryInk)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private let contentMaxWidth: CGFloat = 560

#Preview {
    AnalyticsConsentView(
        store: Store(
            initialState: AnalyticsConsentFeature.State(),
            reducer: AnalyticsConsentFeature.init
        )
    )
}
