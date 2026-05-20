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
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 44, height: 44)

            Text(result.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryInk)

            Text(result.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 337)
    }
}

#Preview {
    VStack(spacing: 24) {
        EmptySearchResultView(result: .pattern)
        EmptySearchResultView(result: .rack)
    }
}
