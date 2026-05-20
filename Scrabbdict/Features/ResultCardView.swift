//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct ResultCardView: View {
    let result: ValidatorResult

    private var resultTitle: String {
        switch result {
        case .valid: "VALID"
        case .invalid: "INVALID"
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

    var body: some View {
        VStack(spacing: 0) {
            Text("THIS WORD IS")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.resultCaption)

            Text(resultTitle)
                .font(.futuraBold(size: 30))
                .foregroundStyle(resultColor)

            if case let .valid(points) = result {
                Divider()
                    .frame(width: 168, height: 1)
                    .overlay(Color.divider)
                    .padding(.vertical, 12)

                Text("\(points)")
                    .font(.futuraBold(size: 30))
                    .foregroundStyle(Color.resultBlue)

                Text("POINTS")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.resultCaption)
            }
        }
        .lineLimit(1)
        .padding(.vertical, resultVerticalPadding)
        .frame(width: 268)
        .background(Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.appShadow, radius: 17, x: 0, y: 14)
    }
}

#Preview {
    VStack(spacing: 24) {
        ResultCardView(result: .valid(points: 29))
        ResultCardView(result: .invalid)
    }
}
