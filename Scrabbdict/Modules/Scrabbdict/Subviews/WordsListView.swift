//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct WordsListView: View {
    let words: [Word]

    @ScaledMetric(relativeTo: .footnote) var pointsHorizontalPadding: CGFloat = 9
    @ScaledMetric(relativeTo: .footnote) var pointsVerticalPadding: CGFloat = 3

    var body: some View {
        List(words, id: \.string) { word in
            HStack(spacing: 0) {
                Text(verbatim: word.string)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primaryInk)

                Spacer(minLength: 16)

                Text(verbatim: "\(word.points)")
                    .font(.footnote.weight(.bold).monospaced())
                    .foregroundStyle(Color.brandAccent)
                    .padding(.horizontal, pointsHorizontalPadding)
                    .padding(.vertical, pointsVerticalPadding)
                    .background(Color.brandAccent.opacity(0.12), in: .capsule)
            }
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: word.string) + Text(verbatim: ", ") + Text(.wordAccessibilityPoints(word.points)))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
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
