//
//  KeyboardView.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit
import TinySwift

final class KeyboardView: UIView {
    
    private var view: UIView?
    
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
}
