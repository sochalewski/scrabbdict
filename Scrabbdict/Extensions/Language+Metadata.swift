//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension Language {
    var name: LocalizedStringResource {
        switch self {
        case .englishCSW: .languageEnglishCswName
        case .englishNWL: .languageEnglishNwlName
        case .englishWOW: .languageEnglishWowName
        case .polish: .languagePolishName
        case .french: .languageFrenchName
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .englishCSW: .languageEnglishCswDescription
        case .englishNWL: .languageEnglishNwlDescription
        case .englishWOW: .languageEnglishWowDescription
        case .polish: .languagePolishDescription
        case .french: .languageFrenchDescription
        }
    }

    var wordCount: Int {
        switch self {
        case .englishCSW: 280_887
        case .englishNWL: 196_601
        case .englishWOW: 195_383
        case .french: 407_128
        case .polish: 2_901_474
        }
    }
}
