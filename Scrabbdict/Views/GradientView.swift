//
//  GradientView.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 13.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import UIKit

final class GradientView: UIView {
    
    override class var layerClass: AnyClass {
        return CAGradientLayer.classForCoder()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let gradientLayer = self.layer as! CAGradientLayer
        gradientLayer.colors = [
            UIColor.white.cgColor,
            UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 0.79).cgColor,
            UIColor.white.withAlphaComponent(0.53).cgColor
        ]
        backgroundColor = UIColor.clear
    }
}
