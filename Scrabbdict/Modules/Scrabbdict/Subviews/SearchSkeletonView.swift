//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct SearchSkeletonView: View {
    enum Variant: Hashable, Sendable {
        case result(showsRackWordsButton: Bool)
        case words
    }

    let variant: Variant

    private var placeholderWords: [Word] {
        [
            Word(string: "placeholder", points: 19),
            Word(string: "dictionary", points: 16),
            Word(string: "matches", points: 14),
            Word(string: "scrabble", points: 14),
            Word(string: "loading", points: 9),
            Word(string: "pattern", points: 9),
            Word(string: "letters", points: 7),
            Word(string: "results", points: 7)
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            if case let .result(showsRackWordsButton) = variant {
                ResultCardView(result: .valid(points: 12))

                if showsRackWordsButton {
                    RackWordsButton(action: {})
                }
            }

            if variant == .words {
                WordsListView(words: placeholderWords)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 32) {
        SearchSkeletonView(variant: .result(showsRackWordsButton: true))
        SearchSkeletonView(variant: .words)
    }
}
