//
//  SettingsViewController.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 10.06.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit

protocol SettingsViewControllerDelegate: class {
    func didFinishPresentation()
}

final class SettingsViewController: UIViewController {
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var descriptionLabel: UILabel!
    
    weak var delegate: SettingsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    private func setup() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableViewHeightConstraint.constant = CGFloat(tableView.numberOfRows(inSection: 0)) * 44.0
        
        let indexPath = IndexPath(row: Language.allValues.index(of: Language.current)!, section: 0)
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = navigationItem.rightBarButtonItem
            navigationItem.rightBarButtonItems = []
        }
    }
    
    private func dismiss() {
        delegate?.didFinishPresentation()
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func cancelButtonAction(_ sender: Any) {
        dismiss()
    }
    
    @IBAction private func saveButtonAction(_ sender: Any) {
        Language.current = Language.allValues[tableView.indexPathForSelectedRow!.row]
        dismiss()
    }
}

extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Language.allValues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = Language.allValues[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        
        descriptionLabel.text = Language.allValues[indexPath.row].description
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .none
    }
}
