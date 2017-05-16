//
//  ViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import BetterSegmentedControl

final class ViewController: UIViewController {
    
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var segmentedControl: BetterSegmentedControl!
    
    private let wordChecker = WordChecker()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        wordChecker.language = .polish
        textField.delegate = self
        
        segmentedControl.titles = ["STANDARD", "TILES"]
        segmentedControl.titleFont = UIFont(name: "AvenirNext-DemiBold", size: 18.0)!
        segmentedControl.selectedTitleFont = UIFont(name: "AvenirNext-DemiBold", size: 18.0)!
        
        textField.layer.shadowColor = UIColor.black.cgColor
        textField.layer.masksToBounds = false
//        textField.layer.cornerRadius = 5.0
        textField.layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
        textField.layer.shadowRadius = 5.0
        textField.layer.shadowOpacity = 0.5
    }
    
    fileprivate func showResultAlert(for word: String) {
        let isRegex = word.contains("?")
        let result = wordChecker.check(word: word)

        switch segmentedControl.index {
        case 0:
            var title = result.title
            var message = result.message
            
            if isRegex {
                let words = wordChecker.regex(from: word)
                let presentableWords = words!.map({ "\($0.string) (\($0.points))" }).joined(separator: ", ")
                let isWordsEmpty = words?.isEmpty ?? true
                title = isWordsEmpty ? Result.notExists.title : Result.exists(points: 0).title
                message = isWordsEmpty ? "Found no words matching the regular expression." : "Words matching the regular expression: \(presentableWords)."
            }
            
            presentAlertController(withTitle: title, message: message, completion: nil)
        case 1:
            if word.characters.count > 8 && wordChecker.language?.isMultipartFile == true {
                presentAlertController(withTitle: "Warning", message: "You've typed more letters than tiles you've got. Change to STANDARD to find if the word exists.", completion: nil)
            } else {
                let words = wordChecker.words(from: word)
                if words?.isEmpty ?? true {
                    presentAlertController(withTitle: result.title, message: "Found no words that can be created from the letters.", completion: nil)
                } else {
                    let presentableWords = words!.map({ "\($0.string) (\($0.points))" }).joined(separator: ", ")
                    presentAlertController(withTitle: result.title, message: "Words formed from the letters: \(presentableWords).", completion: nil)
                }
            }
        default:
            break
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let word = textField.text {
            showResultAlert(for: word)
        }
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }

        let newLength = text.characters.count + string.characters.count - range.length
        
        guard newLength <= 15 else { return false }
        guard !string.isEmpty else { return true }
    
        var allowedCharacterSet = CharacterSet.letters
        allowedCharacterSet.insert(charactersIn: "?")

        guard let rangeOfCharactersAllowed = string.rangeOfCharacter(from: allowedCharacterSet, options: .caseInsensitive) else { return false }
        let count = string.distance(from: rangeOfCharactersAllowed.lowerBound, to: rangeOfCharactersAllowed.upperBound)
        
        return count == string.characters.count
    }
}
