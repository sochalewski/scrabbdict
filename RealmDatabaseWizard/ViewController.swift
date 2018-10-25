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
        
        NSWorkspace.shared.openFile(NSHomeDirectory())
    }
    
    /// Creates a database with `CleverVocabulary` object and writes `Database.realm` to Home directory.
    private func cleverDatabase() {
        try! realm.write {
            realm.deleteAll()
        }
        
        Language.allCases.forEach { language in
            autoreleasepool {
                let string = try! String(contentsOf: language.url, encoding: .utf8)
                let words = string.components(separatedBy: .newlines).sorted { $0.count < $1.count }
                
                let vocabulary = Vocabulary()
                vocabulary.language = language
                
                words.forEach { word in
                    autoreleasepool {
                        let object: StringObject
                        let predicate = NSPredicate(format: "%K == %@", "value", word)
                        if let anObject = realm.objects(StringObject.self).filter(predicate).first {
                            object = anObject
                        } else {
                            object = StringObject()
                            object.value = word
                        }
                        vocabulary.words[word.count].append(object)
                    }
                }
                
                try! realm.write {
                    realm.add(vocabulary)
                }
            }
        }
                
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Database.realm")
        try? FileManager.default.removeItem(at: url)
        try! realm.writeCopy(toFile: url)
    }
}
