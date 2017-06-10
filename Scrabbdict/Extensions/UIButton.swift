//
//  UIButton.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 10.06.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit

private let minimumHitArea = CGSize(width: 44.0, height: 44.0)

extension UIButton {
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isHidden || !isUserInteractionEnabled || alpha < 0.01 { return nil }
        
        let widthToAdd = max(minimumHitArea.width - bounds.width, 0.0)
        let heightToAdd = max(minimumHitArea.height - bounds.height, 0.0)
        let largerFrame = bounds.insetBy(dx: -widthToAdd / 2.0, dy: -heightToAdd / 2.0)
        
        return (largerFrame.contains(point)) ? self : nil
    }
}
