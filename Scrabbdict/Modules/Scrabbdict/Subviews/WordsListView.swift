//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct WordsListView: View {
    let words: [Word]

    var body: some View {
        List(words, id: \.string) { word in
            HStack(spacing: 0) {
                Text(verbatim: word.string)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primaryInk)
                    .lineLimit(1)

                Spacer(minLength: 16)

                Text(verbatim: "\(word.points)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.brandAccent)
                    .padding(.horizontal, 9)
                    .frame(minWidth: 34, minHeight: 22)
                    .background(Color.brandAccent.opacity(0.12), in: Capsule())
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 337)
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
