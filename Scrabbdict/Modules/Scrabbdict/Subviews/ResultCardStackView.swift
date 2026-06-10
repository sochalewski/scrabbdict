//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct ResultCardStackView: View {
    let result: ValidatorResult
    let showsRackWordsButton: Bool
    let rackWordsAction: () -> Void

    init(
        result: ValidatorResult,
        showsRackWordsButton: Bool = false,
        rackWordsAction: @escaping () -> Void = {}
    ) {
        self.result = result
        self.showsRackWordsButton = showsRackWordsButton
        self.rackWordsAction = rackWordsAction
    }

    var body: some View {
        AdaptiveResultCardStackLayout(spacing: 24) {
            ResultCardView(result: result)

            if showsRackWordsButton {
                RackWordsButton(action: rackWordsAction)
            }
        }
    }
}

private struct AdaptiveResultCardStackLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = resolvedWidth(proposal.width, subviews)
        return CGSize(
            width: width,
            height: height(of: subviews, width: width)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let width = resolvedWidth(bounds.width, subviews)
        let originX = bounds.midX - width / 2
        var originY = bounds.minY

        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: width, height: nil))

            subview.place(
                at: CGPoint(x: originX, y: originY),
                proposal: .init(width: width, height: size.height)
            )

            originY += size.height + spacing
        }
    }

    private func resolvedWidth(_ proposedWidth: CGFloat?, _ subviews: Subviews) -> CGFloat {
        let availableWidth = proposedWidth ?? ResultCardView.defaultWidth
        let idealCardWidth = subviews.first?.sizeThatFits(.unspecified).width ?? ResultCardView.defaultWidth

        return min(
            availableWidth,
            max(ResultCardView.defaultWidth, idealCardWidth)
        )
    }

    private func height(of subviews: Subviews, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0

        for subview in subviews {
            height += subview.sizeThatFits(.init(width: width, height: nil)).height
        }

        return height + spacing * CGFloat(max(0, subviews.count - 1))
    }
}

#Preview {
    VStack(spacing: 32) {
        ResultCardStackView(result: .valid(points: 29), showsRackWordsButton: true)
        ResultCardStackView(result: .invalid, showsRackWordsButton: true)
    }
    .padding()
}
