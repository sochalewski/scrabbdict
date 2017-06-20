//
//  ResultView.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 15.06.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit

final class ResultView: UIView {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var pointsLabel: UILabel!
    @IBOutlet private weak var pointsDescriptionLabel: UILabel!

    var result: Result? {
        didSet {
            updateResult()
        }
    }
    private var view: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        view = viewFromNib!
        addSubview(view)
        [titleLabel, descriptionLabel, pointsLabel, pointsDescriptionLabel].forEach { $0.isHidden = true }
    }
    
    private func updateResult() {
        guard let result = result else { return }
        
        [titleLabel, descriptionLabel].forEach { $0.isHidden = false }
        titleLabel.text = result.title
        
        switch result {
        case .exists(let points):
            descriptionLabel.text = "The word exists and is worth"
            pointsLabel.text = "\(points)"
            pointsDescriptionLabel.text = points == 1 ? "POINT" : "POINTS"
            [pointsLabel, pointsDescriptionLabel].forEach { $0.isHidden = false }
        default:
            descriptionLabel.text = result.message
            [pointsLabel, pointsDescriptionLabel].forEach { $0.isHidden = true }

        }
    }
}
