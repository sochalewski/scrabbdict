//
//  ViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import TinySwift

final class ViewController: UIViewController {
    
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    
    private let wordChecker = WordChecker()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        wordChecker.language = .polish
        textField.delegate = self
    }
    
    fileprivate func showResultAlert(for word: String) {
        let result = wordChecker.check(word: word)

        switch segmentedControl.selectedSegmentIndex {
        case 0:
            presentAlertController(withTitle: result.title, message: result.message, completion: nil)
        case 1, 2:
            if word.characters.count > 8 && wordChecker.language?.isMultipartFile == true {
                presentAlertController(withTitle: "Warning", message: "You've typed has more letters than tiles you've got. Change to STANDARD to find if the word exists.", completion: nil)
            } else {
                let isRegex = segmentedControl.selectedSegmentIndex == 2
                let words = isRegex ? wordChecker.regex(from: word) : wordChecker.words(from: word)
                if words?.isEmpty ?? true {
                    presentAlertController(withTitle: result.title, message: (isRegex ? "" : result.message + "\n\n") + "Found no words that can be created from the letters.", completion: nil)
                } else {
                    let presentableWords = words!.map({ "\($0.string) (\($0.points))" }).joined(separator: ", ")
                    presentAlertController(withTitle: result.title, message: (isRegex ? "" : result.message + "\n\n") + "Words formed from the letters: \(presentableWords).", completion: nil)
                }
            }
        default:
            break
        }
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let word = textField.text {
            showResultAlert(for: word)
        }
        
        return true
    }
}
