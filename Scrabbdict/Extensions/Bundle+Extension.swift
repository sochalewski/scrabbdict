//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension Bundle {
    static func localizationBundle(for locale: Locale) -> Bundle {
        guard
            let languageCode = locale.language.languageCode?.identifier,
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }

    func localizedString(forKey key: String, locale: Locale, arguments: CVarArg...) -> String {
        let format = localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: locale, arguments: arguments)
    }
}
