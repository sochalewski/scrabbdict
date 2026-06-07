//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation
import SwiftUI

struct ResultCardView: View {
    @Environment(\.locale) var locale

    let result: ValidatorResult

    private var resultTitle: LocalizedStringResource {
        switch result {
        case .valid: .resultValid
        case .invalid: .resultInvalid
        }
    }

    private var resultColor: Color {
        switch result {
        case .valid: .resultGreen
        case .invalid: .resultRed
        }
    }

    private var resultVerticalPadding: CGFloat {
        switch result {
        case .valid: 20
        case .invalid: 16
        }
    }

    private var accessibilityLabel: Text {
        switch result {
        case let .valid(points):
            Text(.resultAccessibilityValid) + Text(verbatim: ", ") + Text(.wordAccessibilityPoints(points))
        case .invalid:
            Text(.resultAccessibilityInvalid)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(.resultCaption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.resultCaption)

            Text(resultTitle)
                .font(.title.weight(.black))
                .foregroundStyle(resultColor)

            if case let .valid(points) = result {
                Divider()
                    .frame(height: 1)
                    .overlay(Color.divider)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Text(verbatim: "\(points)")
                    .font(.title.weight(.black))
                    .foregroundStyle(Color.resultBlue)

                Text(verbatim: localizedPointNoun(for: points))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.resultCaption)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, resultVerticalPadding)
        .padding(.horizontal, 16)
        .frame(width: 268)
        .background(Color.elevatedSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.appShadow, radius: 17, x: 0, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func localizedPointNoun(for points: Int) -> String {
        localizedResultPoints(for: points, locale: locale)
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localizedResultPoints(for points: Int, locale: Locale) -> String {
        Bundle.localizationBundle(for: locale)
            .localizedString(forKey: "result.points", locale: locale, arguments: points)
    }
}

#Preview {
    VStack(spacing: 24) {
        ResultCardView(result: .valid(points: 29))
        ResultCardView(result: .invalid)
    }
}
