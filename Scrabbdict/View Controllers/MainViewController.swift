//
//  MainViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import SwiftSpinner
import Crashlytics

enum Mode: String {
    case standard = "Standard"
    case tiles = "Tiles"
}

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

final class MainViewController: UIViewController {
    
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet weak var resultView: ResultView!
    @IBOutlet private weak var modeSwitch: UISwitch!
    @IBOutlet private weak var modeLabel: UILabel!
    
    fileprivate let wordChecker = WordChecker()
    private var mode = Mode.standard {
        didSet {
            UIView.transition(with: modeLabel, duration: 0.35, options: .transitionCrossDissolve, animations: {
                self.modeLabel.text = self.mode.rawValue
            }, completion: nil)
            
            switch mode {
            case .standard: textField.placeholder = "Word (? for blank)"
            case .tiles: textField.placeholder = "Letters"
            }
        }
    }
    fileprivate var words: [Word]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        SwiftSpinner.setTitleFont(UIFont(name: "AvenirNext-Medium", size: 16.0))
        modeSwitch.setOn(false, animated: false)
        modeSwitchValueChanged(modeSwitch)
        
        setTableView(visible: false, animated: false)
        setResultView(visible: false, animated: false)
        
        wordChecker.language = Language.current
        textField.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorColor = UIColor.black.withAlphaComponent(0.1)
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView()
        
        if UIScreen.main.size <= .inch4 {
            textField.font = UIFont(name: textField.font!.fontName, size: textField.font!.pointSize - 2.0)
        }
    }
    
    @IBAction func modeSwitchValueChanged(_ sender: UISwitch) {
        mode = sender.isOn ? .tiles : .standard
    }
    
    @IBAction func searchButtonAction(_ sender: Any) {
        search()
    }
    
    fileprivate func search() {
        if let word = textField.text, !word.isEmpty {
            showResultAlert(for: word)
        }
    }
    
    fileprivate func showResultAlert(`for` word: String) {
        let isRegex = word.contains("?")
        let isStandard = mode == .standard
        let isWordLongerThanEight = word.characters.count > 8
        let cannotProceed = !isStandard && (isRegex || isWordLongerThanEight)
        
        if cannotProceed {
            presentAlertController(withTitle: "Warning", message: "You've typed more letters than tiles you've got. Choose STANDARD or remove blanks (?) to proceed.", completion: nil)
            words = nil
            setTableView(visible: false)
            setResultView(visible: false)
            
            return
        }

        textField.resignFirstResponder()
        if !(isStandard && !isRegex) {
            SwiftSpinner.show("Searching…")
        }

        let semaphore = DispatchSemaphore(value: 1)
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            semaphore.wait()
            
            let result = self.wordChecker.check(word: word)
            
            switch self.mode {
            case .standard:
                if isRegex {
                    self.words = self.wordChecker.regex(from: word)
                } else {
                    self.words = nil
                }
            case .tiles:
                self.words = self.wordChecker.words(from: word)
            }
            
            semaphore.signal()
            
            DispatchQueue.main.async {
                SwiftSpinner.hide()
                
                guard self.words == nil else {
                    self.setTableView(visible: true)
                    self.setResultView(visible: false)
                    self.tableView.reloadData()
                    return
                }
                
                self.setTableView(visible: false)
                switch self.mode {
                case .standard:
                    if isRegex {
                        self.presentAlertController(withTitle: "Oops!", message: "Found no words matching the regular expression.", completion: nil)
                    } else {
                        self.resultView.result = result
                        self.setResultView(visible: true)
                    }
                case .tiles:
                    self.presentAlertController(withTitle: "Oops!", message: "Found no words that can be made only from these letters.", completion: nil)
                }
            }
        }
    }
    
    fileprivate func setTableView(visible: Bool, animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.5 : 0.0) {
            self.tableView.alpha = visible ? 1.0 : 0.0
        }
    }
    
    fileprivate func setResultView(visible: Bool, animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.5 : 0.0) {
            self.resultView.alpha = visible ? 1.0 : 0.0
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let settingsViewController = (segue.destination as! UINavigationController).viewControllers.first! as! SettingsViewController
        settingsViewController.delegate = self
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        search()
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        setResultView(visible: false)
        
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

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
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

extension MainViewController: SettingsViewControllerDelegate {
    func didFinishPresentation() {
        guard wordChecker.language != Language.current else { return }
        Answers.logCustomEvent(withName: "Language changed", customAttributes: ["language" : Language.current.name])
        setTableView(visible: false)
        setResultView(visible: false)
        SwiftSpinner.show("Changing dictionary…")
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.wordChecker.language = Language.current
            SwiftSpinner.hide()
        }
    }
}
