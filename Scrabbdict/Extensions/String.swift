//
//  String.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 10.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import Foundation

extension String {
    var isLengthValid: Bool {
        return 2...String.maximumWordLength ~= count
    }
    
    static let maximumWordLength = 15
}
