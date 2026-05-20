//
//  Scrabbdict
//  Copyright © 2017 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Firebase
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if !targetEnvironment(simulator) && !DEBUG
            FirebaseApp.configure()
        #endif

        return true
    }
}
