//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation
import SwiftUI

struct ResultCardView: View {
    static let defaultWidth: CGFloat = 268

    let result: ValidatorResult

    @Environment(\.locale) var locale

    var body: some View {
        VStack(spacing: 0) {
            Text(.resultCaption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.resultCaption)

            Text(resultTitle)
                .font(.title.weight(.black))
                .foregroundStyle(resultColor)

            if case let .valid(points) = result {
                Divider()
                    .frame(height: 1)
                    .overlay(.divider)
                    .padding(.vertical, 12)

                Text(verbatim: "\(points)")
                    .font(.title.weight(.black))
                    .foregroundStyle(.resultBlue)

                Text(verbatim: localizedPointNoun(for: points))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.resultCaption)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .frame(minWidth: Self.defaultWidth, maxWidth: .infinity)
        .background(.elevatedSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .appShadow, radius: 17, x: 0, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

private extension ResultCardView {
    var resultTitle: LocalizedStringResource {
        switch result {
        case .valid: .resultValid
        case .invalid: .resultInvalid
        }
    }

    var resultColor: Color {
        switch result {
        case .valid: .resultGreen
        case .invalid: .resultRed
        }
    }

    var accessibilityLabel: Text {
        switch result {
        case .valid: Text(.resultAccessibilityValid)
        case .invalid: Text(.resultAccessibilityInvalid)
        }
    }

    var accessibilityValue: Text? {
        switch result {
        case let .valid(points): Text(.wordAccessibilityPoints(points))
        case .invalid: nil
        }
    }

    func localizedPointNoun(for points: Int) -> String {
        localizedResultPoints(for: points, locale: locale)
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func localizedResultPoints(for points: Int, locale: Locale) -> String {
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
