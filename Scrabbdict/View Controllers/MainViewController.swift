//
//  MainViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import SwiftSpinner
import FirebaseAnalytics

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
    @IBOutlet private weak var modeSwitch: UISwitch!
    @IBOutlet private weak var modeLabel: UILabel!
    
    private weak var resultView: UIView?
    
    private let validator = Validator()
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
    private var words = [Word]()
    private var isSpinnerVisible = false {
        didSet { setNeedsStatusBarAppearanceUpdate() }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isSpinnerVisible ? .lightContent : .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        SwiftSpinner.setTitleFont(UIFont(name: "AvenirNext-Medium", size: 16.0))
        modeSwitch.setOn(false, animated: false)
        modeSwitchValueChanged(modeSwitch)
        
        setTableView(visible: false, animated: false)
        dismissResultView(animated: false)
        
        validator.language = Language.current
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
    
    @IBAction private func modeSwitchValueChanged(_ sender: UISwitch) {
        view.endEditing(true)
        dismissResultView()
        setTableView(visible: false)
        
        mode = sender.isOn ? .tiles : .standard
    }
    
    @IBAction private func searchButtonAction(_ sender: Any) {
        search()
    }
    
    private func search() {
        if let word = textField.text, !word.isEmpty {
            showResultAlert(for: word)
        }
    }
    
    private func showResultAlert(for word: String) {
        let isRegex = word.contains("?")
        let isStandard = mode == .standard
        
        func onError(_ error: ValidatorError) {
            presentAlertController(withTitle: "Warning", message: error.localizedDescription, completion: nil)
            setTableView(visible: false)
            dismissResultView()
        }
        
        textField.resignFirstResponder()
        if !(isStandard && !isRegex) {
            showSpinner(title: "Searching…")
        }
        
        let closureToCallWhenComplete: ((ValidatorResult?) -> ()) = { result in
            DispatchQueue.main.async {
                self.hideSpinner()
                
                guard self.words.isEmpty else {
                    self.setTableView(visible: true)
                    self.dismissResultView()
                    self.tableView.reloadData()
                    return
                }
                
                self.setTableView(visible: false)
                switch self.mode {
                case .standard:
                    if isRegex {
                        self.presentAlertController(withTitle: "Oops!", message: "Found no words matching the regular expression.", completion: nil)
                    } else {
                        guard let result = result else { return }
                        self.showResultView(result: result)
                    }
                case .tiles:
                    guard self.presentedViewController == nil else { return }
                    self.presentAlertController(withTitle: "Oops!", message: "Found no words that can be made only from these letters.", completion: nil)
                }
            }
        }
        
        switch mode {
        case .standard:
            if isRegex {
                validator.regex(phrase: word) { [unowned self] result in
                    switch result {
                    case .success(let words):
                        self.words = words
                    case .failure:
                        self.words = []
                    }
                    closureToCallWhenComplete(nil)
                }
            } else {
                words = []
                validator.check(word: word) { result in
                    switch result {
                    case .success(let result):
                        closureToCallWhenComplete(result)
                    case .failure:
                        closureToCallWhenComplete(nil)
                    }
                }
            }
        case .tiles:
            validator.words(from: word) { [unowned self] result in
                switch result {
                case .success(let words):
                    self.words = words
                case .failure(let error):
                    self.words = []
                    DispatchQueue.main.async { onError(error) }
                }
                closureToCallWhenComplete(nil)
            }
        }
    }
    
    private func setTableView(visible: Bool, animated: Bool = true) {
        // If not visible, then stop scrolling to not crash on tableView(_:cellForRowAt:).
        // If visible, scroll to the top.
        let contentOffset: CGPoint = visible ? .zero : tableView.contentOffset
        tableView.setContentOffset(contentOffset, animated: false)

        UIView.animate(withDuration: animated ? 0.4 : 0.0) {
            self.tableView.alpha = visible ? 1.0 : 0.0
        }
    }
    
    private func showResultView(result: ValidatorResult, animated: Bool = true) {
        dismissResultView(animated: false)
        
        let resultView = ResultView(result: result)
        view.addSubview(resultView)
        self.resultView = resultView
        resultView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor).isActive = true
        let constraint = resultView.topAnchor.constraint(equalTo: bottomLayoutGuide.bottomAnchor)
        constraint.isActive = true
        view.layoutIfNeeded()
        
        constraint.isActive = false
        resultView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -10.0).isActive = true

        UIView.animate(withDuration: animated ? 0.4 : 0.0, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 4.0, options: .curveEaseIn, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    private func dismissResultView(animated: Bool = true) {
        guard let resultView = resultView else { return }
        
        UIView.animate(withDuration: animated ? 0.4 : 0.0, animations: {
            resultView.alpha = 0.0
        }) { _ in
            resultView.removeFromSuperview()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let settingsViewController = (segue.destination as! UINavigationController).viewControllers.first! as! SettingsViewController
        settingsViewController.delegate = self
        settingsViewController.preferredContentSize = CGSize(width: 375.0, height: 410.0)
    }
}

extension MainViewController {
    private func showSpinner(title: String) {
        SwiftSpinner.show(title)
        isSpinnerVisible = true
    }
    
    private func hideSpinner() {
        SwiftSpinner.hide { 
            self.isSpinnerVisible = false
        }
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        search()
        
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        dismissResultView()
        setTableView(visible: false)
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        dismissResultView()
        setTableView(visible: false)
        
        guard let text = textField.text else { return true }

        let newLength = text.count + string.count - range.length
        
        guard newLength <= String.maximumWordLength else { return false }
        guard !string.isEmpty else { return true }
    
        var allowedCharacterSet = CharacterSet.letters
        allowedCharacterSet.insert(charactersIn: "?")

        guard let rangeOfCharactersAllowed = string.rangeOfCharacter(from: allowedCharacterSet, options: .caseInsensitive) else { return false }
        let count = string.distance(from: rangeOfCharactersAllowed.lowerBound, to: rangeOfCharactersAllowed.upperBound)
        
        return count == string.count
    }
}

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return words.isEmpty ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return words.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! WordTableViewCell
        cell.word = words[indexPath.row].string
        cell.points = words[indexPath.row].points
        
        return cell
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

extension MainViewController: SettingsViewControllerDelegate {
    func didFinishPresentation() {
        guard validator.language != Language.current else { return }
        Analytics.logEvent("language_changed", parameters: ["language" : Language.current.name])
        setTableView(visible: false)
        dismissResultView()
        validator.language = Language.current
    }
}
