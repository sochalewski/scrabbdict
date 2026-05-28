//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

struct ScrabbdictAlert: Hashable, Sendable, Identifiable {
    enum Kind: Hashable, Sendable {
        case dictionaryUnavailable
    }

    let kind: Kind

    var title: LocalizedStringResource {
        switch kind {
        case .dictionaryUnavailable: .alertWarningTitle
        }
    }

    var message: LocalizedStringResource {
        switch kind {
        case .dictionaryUnavailable: .errorDictionaryUnavailable
        }
    }

    var id: Self {
        self
    }
}
