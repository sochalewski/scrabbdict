//
//  ViewController.swift
//  DictionarySplitter
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet private weak var splitButton: NSButton!
    
    private var fileURL: URL? {
        didSet {
            splitButton.isEnabled = (fileURL != nil)
        }
    }
    lazy private var openPanel: NSOpenPanel = {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["txt"]
        
        return openPanel
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        fileURL = nil
    }

    @IBAction func openButtonAction(_ sender: Any) {
        guard openPanel.runModal() == NSModalResponseOK else { return }
        fileURL = openPanel.url
    }

    @IBAction func splitButtonAction(_ sender: Any) {
        guard let fileURL = fileURL, let file = try? String(contentsOf: fileURL) else {
            splitButton.isEnabled = false
            return
        }
        
        let words = file.components(separatedBy: .whitespacesAndNewlines).filter { $0.characters.count > 0 }
        let ranges = [0...10, 11...11, 12...12, 13...13, 14...14, 15...15, 16...Int.max]
        
        ranges.forEach { range in
            autoreleasepool {
                let filterWords = words.filter { range.contains($0.characters.count) }
                guard !filterWords.isEmpty else { return }
                let newFileName = fileURL.deletingPathExtension().lastPathComponent + "_\(range.upperBound).txt"
                let url = fileURL.deletingLastPathComponent().appendingPathComponent(newFileName)
                try? filterWords.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
}
