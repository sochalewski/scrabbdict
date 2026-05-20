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
            Label("Find words from letters", systemImage: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: 268)
                .frame(height: 46)
                .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: Color.appShadow, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RackWordsButton(action: {})
}
