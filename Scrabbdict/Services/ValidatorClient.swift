//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

struct ValidatorClient: Sendable {
    var check: @Sendable (String) async throws(ValidatorError) -> ValidatorResult
    var words: @Sendable (String) async throws(ValidatorError) -> [Word]
    var regex: @Sendable (String) async throws(ValidatorError) -> [Word]
}

extension ValidatorClient: DependencyKey {
    static let liveValue: Self = {
        let validator = Validator()

        return ValidatorClient(
            check: { word async throws(ValidatorError) in
                try await validator.check(word: word)
            },
            words: { letters async throws(ValidatorError) in
                try await validator.words(from: letters)
            },
            regex: { phrase async throws(ValidatorError) in
                try await validator.regex(phrase: phrase)
            }
        )
    }()

    static let testValue = Self(
        check: unimplemented("\(Self.self).check", throwing: ValidatorError.dictionaryUnavailable),
        words: unimplemented("\(Self.self).words", throwing: ValidatorError.dictionaryUnavailable),
        regex: unimplemented("\(Self.self).regex", throwing: ValidatorError.dictionaryUnavailable)
    )
}

extension DependencyValues {
    var validatorClient: ValidatorClient {
        get { self[ValidatorClient.self] }
        set { self[ValidatorClient.self] = newValue }
    }
}
