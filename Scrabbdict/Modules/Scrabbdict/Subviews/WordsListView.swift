//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct WordsListView: View {
    let words: [Word]

    @Environment(\.resultContentLayout) var resultContentLayout
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.displayScale) var displayScale
    @ScaledMetric(relativeTo: .footnote) var pointsHorizontalPadding: CGFloat = 9
    @ScaledMetric(relativeTo: .footnote) var pointsVerticalPadding: CGFloat = 3

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(words, id: \.string) { word in
                    row(for: word)
                }
            }
        }
    }
}

private extension WordsListView {
    var rowMargin: CGFloat {
        horizontalSizeClass == .regular ? 20 : 16
    }

    func row(for word: Word) -> some View {
        rowContent(for: word)
            .padding(.horizontal, resultContentLayout.horizontalPadding)
            .frame(maxWidth: resultContentLayout.maxWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: word.string))
            .accessibilityValue(Text(.wordAccessibilityPoints(word.points)))
            .padding(.vertical, 15)
            .overlay(alignment: .bottom) {
                separator
            }
            .padding(.horizontal, rowMargin)
    }

    func rowContent(for word: Word) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: word.string)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primaryInk)

            Spacer(minLength: 16)

            Text(verbatim: "\(word.points)")
                .font(.footnote.weight(.bold).monospaced())
                .foregroundStyle(.brandAccent)
                .padding(.horizontal, pointsHorizontalPadding)
                .padding(.vertical, pointsVerticalPadding)
                .background(.brandAccent.opacity(0.12), in: .capsule)
        }
    }

    var separator: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1 / displayScale)
            .padding(.horizontal, resultContentLayout.horizontalPadding)
            .frame(maxWidth: resultContentLayout.maxWidth)
    }
}

struct ResultContentLayout {
    var maxWidth: CGFloat = .infinity
    var horizontalPadding: CGFloat = 0
}

extension EnvironmentValues {
    @Entry var resultContentLayout = ResultContentLayout()
}

extension View {
    func resultContentLayout(maxWidth: CGFloat, horizontalPadding: CGFloat) -> some View {
        environment(
            \.resultContentLayout,
            ResultContentLayout(maxWidth: maxWidth, horizontalPadding: horizontalPadding)
        )
    }
}

#Preview {
    WordsListView(
        words: [
            Word(string: "nastier", points: 7),
            Word(string: "retains", points: 7),
            Word(string: "stainer", points: 7),
            Word(string: "retina", points: 6)
        ]
    )
}
