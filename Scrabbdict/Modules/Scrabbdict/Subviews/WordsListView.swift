//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct WordsListView: View {
    let words: [Word]

    @Environment(\.resultContentLayout) var resultContentLayout
    @ScaledMetric(relativeTo: .footnote) var pointsHorizontalPadding: CGFloat = 9
    @ScaledMetric(relativeTo: .footnote) var pointsVerticalPadding: CGFloat = 3

    var body: some View {
        List(words, id: \.string) { word in
            listRow(for: word, isFirst: word.string == words.first?.string)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
    }
}

private extension WordsListView {
    func listRow(for word: Word, isFirst: Bool) -> some View {
        rowContent(for: word)
            .padding(.horizontal, resultContentLayout.horizontalPadding)
            .frame(maxWidth: resultContentLayout.maxWidth)
            .frame(maxWidth: .infinity)
            .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                listRowSeparatorHorizontalInset(for: dimensions.width)
            }
            .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                dimensions.width - listRowSeparatorHorizontalInset(for: dimensions.width)
            }
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: word.string))
            .accessibilityValue(Text(.wordAccessibilityPoints(word.points)))
            .listRowSeparator(isFirst ? .hidden : .automatic, edges: .top)
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

    func listRowSeparatorHorizontalInset(for rowWidth: CGFloat) -> CGFloat {
        guard resultContentLayout.maxWidth.isFinite else {
            return resultContentLayout.horizontalPadding
        }

        let constrainedWidth = min(rowWidth, resultContentLayout.maxWidth)
        return ((rowWidth - constrainedWidth) / 2) + resultContentLayout.horizontalPadding
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
