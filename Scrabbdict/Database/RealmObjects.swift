//
//  RealmObjects.swift
//  CollectionPerformance
//
//  Created by Piotr Sochalewski on 10.01.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import RealmSwift

/// A Vocabulary object that contains multiple lists of words.
final class Vocabulary: Object {
    
    var language: Language {
        get { return Language(rawValue: _language)! }
        set { _language = newValue.rawValue }
    }
    
    @Persisted private var _language = ""
    
    // List<List<StringObject>> is not allowed :/
    @Persisted var words2: List<StringObject>
    @Persisted var words3: List<StringObject>
    @Persisted var words4: List<StringObject>
    @Persisted var words5: List<StringObject>
    @Persisted var words6: List<StringObject>
    @Persisted var words7: List<StringObject>
    @Persisted var words8: List<StringObject>
    @Persisted var words9: List<StringObject>
    @Persisted var words10: List<StringObject>
    @Persisted var words11: List<StringObject>
    @Persisted var words12: List<StringObject>
    @Persisted var words13: List<StringObject>
    @Persisted var words14: List<StringObject>
    @Persisted var words15: List<StringObject>
    
    /// An array of list of String objects sorted from zero to fifteen letters.
    lazy private(set) var words: [List<StringObject>] = {
        return [List<StringObject>(), List<StringObject>(), words2, words3, words4, words5, words6, words7, words8, words9, words10, words11, words12, words13, words14, words15]
    }()
}

/// A String object.
final class StringObject: Object {
    
    /// A String value.
    @Persisted(indexed: true) var value: String
}
