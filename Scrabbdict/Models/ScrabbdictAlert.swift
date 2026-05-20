//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

struct ScrabbdictAlert: Hashable, Sendable, Identifiable {
    let title: String
    let message: String

    var id: Self {
        self
    }
}
