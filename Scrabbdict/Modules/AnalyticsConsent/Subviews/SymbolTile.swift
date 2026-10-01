//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct SymbolTile: View {
    let systemImage: String
    let size: CGFloat

    var body: some View {
        let cornerRadius = size * 0.14

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .TableBackground.tileTop,
                            .TableBackground.tileBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.TableBackground.tileStroke, lineWidth: 0.8)

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .TableBackground.tileHighlight,
                            .TableBackground.tileBevelBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color.TableBackground.tileInk)
        }
        .frame(width: size, height: size)
        .shadow(color: .TableBackground.tileShadow, radius: 1.5, x: 0.5, y: 1.0)
        .shadow(color: .TableBackground.tileElevatedShadow, radius: 7.0, x: 1.5, y: 3.5)
    }
}

#Preview {
    SymbolTile(systemImage: "hand.raised.fill", size: 64)
        .padding()
}
