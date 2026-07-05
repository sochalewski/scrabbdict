//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension String {
    var isLengthValid: Bool {
        2...String.maximumWordLength ~= count
    }

    var sanitizedWordQuery: String {
        let filtered = precomposedStringWithCanonicalMapping.filter { character in
            character.isLetter || character == "?"
        }
        return String(filtered.prefix(String.maximumWordLength))
    }

    var wordQueryAccessibilityValue: String {
        guard !isEmpty else { return self }

        let isPattern = contains("?")
        let accessibility = uppercased()
            .map(String.init)
            .joined(separator: ", ")
            .replacingOccurrences(of: "?", with: String(localized: .searchModeQuestionMark))

        return isPattern ? accessibility : "\(self) (\(accessibility))"
    }

    private static let maximumWordLength = 15
}
