//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct RackWordsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(.rackWordsButtonTitle, systemImage: "magnifyingglass")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.brandAccent)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .shadow(color: .appShadow, radius: 10, x: 0, y: 5)
    }
}

#Preview {
    RackWordsButton(action: {})
}
