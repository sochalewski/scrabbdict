//
//  KeyView.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit

//@IBDesignable
final class KeyView: UIView {
    
    @IBOutlet private weak var letterLabel: UILabel!
    @IBOutlet private weak var pointsLabel: UILabel!
    
    private var view: UIView?
    
    @IBInspectable var letter: String? {
        didSet {
            letterLabel?.text = letter
        }
    }
    
    @IBInspectable var points: Int? {
        didSet {
            pointsLabel?.text = "\(points ?? 0)"
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        view = viewFromNib
        addSubview(view!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        view = viewFromNib
        addSubview(view!)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 3.0
        layer.masksToBounds = true
    }
}
