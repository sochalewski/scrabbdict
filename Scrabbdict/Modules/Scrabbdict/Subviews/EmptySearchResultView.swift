//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct EmptySearchResultView: View {
    let result: EmptySearchResult

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title.weight(.semibold))
                .foregroundStyle(.secondaryText)
                .frame(width: 44, height: 44)

            Text(result.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primaryInk)

            Text(result.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 24) {
        EmptySearchResultView(result: .pattern)
        EmptySearchResultView(result: .rack)
    }
}
