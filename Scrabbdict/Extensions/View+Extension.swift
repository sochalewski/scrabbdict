//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

extension View {
    @ViewBuilder
    func accessibilityValue(_ value: Text?) -> some View {
        if let value {
            accessibilityValue(value)
        } else {
            self
        }
    }
}
