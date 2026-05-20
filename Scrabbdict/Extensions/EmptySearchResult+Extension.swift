//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

extension EmptySearchResult {
    static let pattern = EmptySearchResult(
        title: "No matches",
        message: "No words match this pattern."
    )

    static let rack = EmptySearchResult(
        title: "No words",
        message: "No valid words can be made from these letters."
    )
}
