//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI

@main
struct ScrabbdictApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ScrabbdictView(
                store: Store(initialState: ScrabbdictFeature.State()) {
                    ScrabbdictFeature()
                }
            )
        }
    }
}
