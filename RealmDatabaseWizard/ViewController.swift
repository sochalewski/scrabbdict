//
//  ViewController.swift
//  RealmDatabaseWizard
//
//  Created by Piotr Sochalewski on 02.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import Cocoa
import RealmSwift

extension Language {
    var url: URL {
        return Bundle.main.url(forResource: rawValue, withExtension: "txt")!
    }
}

final class ViewController: NSViewController {
    
    private let realm = try! Realm()
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        cleverDatabase()
        textFiles()
    }
    
    /// Creates a database with `CleverVocabulary` object and writes `Database.realm` to Home directory.
    private func cleverDatabase() {
        try! realm.write {
            realm.deleteAll()
        }
        
        var vocabularies = [Vocabulary]()
        
        Language.allValues.forEach { language in
            autoreleasepool {
                let string = try! String(contentsOf: language.url, encoding: .utf8)
                let words = string.components(separatedBy: .newlines)
                
                let vocabulary = Vocabulary()
                vocabulary.language = language
                
                words.forEach { word in
                    autoreleasepool {
                        let object = StringObject()
                        object.value = word
                        vocabulary.words[word.count].append(object)
                    }
                }
                
                vocabularies.append(vocabulary)
            }
        }
        
        try! realm.write {
            realm.add(vocabularies)
        }
        
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Database.realm")
        try? FileManager.default.removeItem(at: url)
        try! realm.writeCopy(toFile: url)
    }
    
    private func textFiles() {
        Language.allValues.forEach { language in
            autoreleasepool {
                let string = try! String(contentsOf: language.url, encoding: .utf8)
                let words = string.components(separatedBy: .newlines)
                let newWords = words.filter { $0.count <= 8 }
                
                let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("\(language.rawValue).txt")
                try? FileManager.default.removeItem(at: url)

                try! newWords.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
