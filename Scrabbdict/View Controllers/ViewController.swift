//
//  ViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import BetterSegmentedControl
import SwiftSpinner

final class WordTableViewCell: UITableViewCell {
    @IBOutlet private weak var wordLabel: UILabel!
    @IBOutlet private weak var pointsLabel: UILabel!
    
    var word: String? {
        set { wordLabel.text = newValue }
        get { return wordLabel.text }
    }
    var points: Int? {
        set {
            guard let newValue = newValue else { return }
            pointsLabel.text = "\(newValue)" }
        get {
            guard let text = wordLabel.text else { return nil }
            return Int(text)
        }
    }
}

final class ViewController: UIViewController {
    
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var segmentedControl: BetterSegmentedControl!
    @IBOutlet private weak var tableView: UITableView!
    
    private let wordChecker = WordChecker()
    fileprivate var words: [Word]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setTableView(visible: false, animation: false)
        
        wordChecker.language = .polish
        textField.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.2)
        tableView.separatorInset = .zero
        
        segmentedControl.titles = ["STANDARD", "TILES"]
        segmentedControl.titleFont = UIFont(name: "AvenirNext-DemiBold", size: 18.0)!
        segmentedControl.selectedTitleFont = segmentedControl.titleFont
        
        textField.layer.shadowColor = UIColor.black.cgColor
        textField.layer.masksToBounds = false
        textField.layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
        textField.layer.shadowRadius = 5.0
        textField.layer.shadowOpacity = 0.5
    }
    
    fileprivate func showResultAlert(`for` word: String) {
        let isRegex = word.contains("?")
        
        let isRegexOrBlanks = isRegex || segmentedControl.index == 1
        let isWordLongerThanEight = word.characters.count > 8
        let isLanguageMultipart = wordChecker.language?.isMultipartFile == true
        let cannotProceed = [isRegexOrBlanks, isWordLongerThanEight, isLanguageMultipart].reduce(true) { $0 == $1 }
        
        if cannotProceed {
            presentAlertController(withTitle: "Warning", message: "You've typed more letters than tiles you've got. Choose STANDARD or remove blanks (?) to proceed.", completion: nil)
            words = nil
            setTableView(visible: false)
            
            return
        }

        textField.resignFirstResponder();
        SwiftSpinner.show("Searching…")

        let semaphore = DispatchSemaphore(value: 1)
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            semaphore.wait()
            
            let result = self.wordChecker.check(word: word)
            
            switch self.segmentedControl.index {
            case 0:
                if isRegex {
                    self.words = self.wordChecker.regex(from: word)
                } else {
                    self.words = nil
                }
                
            case 1:
                self.words = self.wordChecker.words(from: word)
                
            default:
                break
            }
            
            semaphore.signal()
            
            DispatchQueue.main.async {
                SwiftSpinner.hide()
                
                guard self.words == nil else { self.setTableView(visible: true); self.tableView.reloadData(); return }
                self.setTableView(visible: false)
                switch self.segmentedControl.index {
                case 0:
                    if isRegex {
                        self.presentAlertController(withTitle: "Oops!", message: "Found no words matching the regular expression.", completion: nil)
                    } else {
                        self.presentAlertController(withTitle: result.title, message: result.message, completion: nil)
                    }
                    
                case 1:
                    self.presentAlertController(withTitle: "Oops!", message: "Found no words that can be created from the letters.", completion: nil)
                    
                default:
                    break
                }
            }
        }
    }
    
    fileprivate func setTableView(visible: Bool, animation: Bool = true) {
        UIView.animate(withDuration: animation ? 0.5 : 0.0) { 
            self.tableView.alpha = visible ? 1.0 : 0.0
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

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return words?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! WordTableViewCell
        cell.word = words?[indexPath.row].string
        cell.points = words?[indexPath.row].points
        
        return cell
    }
}
