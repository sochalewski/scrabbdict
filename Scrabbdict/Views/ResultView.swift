//
//  ResultView.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 15.06.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import UIKit

final class ResultView: UIView {
    
    private lazy var topLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "THE WORD IS"
        label.font = .futura(size: 20.0)
        label.textColor = .grayLabel
        return label
    }()
    
    private lazy var resultLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .futura(size: 24.0)
        return label
    }()
    
    private lazy var pointsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .futura(size: 24.0)
        label.textColor = .blueLabel
        return label
    }()
    
    private lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "POINTS"
        label.font = .futura(size: 20.0)
        label.textColor = .grayLabel
        return label
    }()
    
    private lazy var lineView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.applySketchShadow(color: .black, alpha: 0.2, x: 0.0, y: 1.0, blur: 2.0, spread: 0.0)
        return view
    }()
    
    private let result: ValidatorResult
    
    init(result: ValidatorResult) {
        self.result = result
        super.init(frame: .zero)
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .white
        layer.cornerRadius = 8.0
        clipsToBounds = false
        
        switch result {
        case .exists(let points):
            [topLabel, resultLabel, pointsLabel, bottomLabel, lineView].forEach(addSubview(_:))
            resultLabel.text = "VALID"
            resultLabel.textColor = .greenLabel
            pointsLabel.text = "\(points)"
        case .notExists:
            [topLabel, resultLabel].forEach(addSubview(_:))
            resultLabel.text = "INVALID"
            resultLabel.textColor = .redLabel
        }
        
        layer.applySketchShadow(color: .black, alpha: 0.2, x: 0.0, y: 2.0, blur: 18.0, spread: 0.0)
        
        applyConstraints()
    }
    
    private func applyConstraints() {
        let vertical: CGFloat
        switch result {
        case .exists:
            vertical = 20.0
            
            [
                lineView.centerXAnchor.constraint(equalTo: centerXAnchor),
                lineView.centerYAnchor.constraint(equalTo: centerYAnchor),
                lineView.heightAnchor.constraint(equalToConstant: 1.0),
                lineView.widthAnchor.constraint(equalToConstant: 168.0),
                lineView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 12.0),
                
                pointsLabel.heightAnchor.constraint(equalToConstant: 31.0),
                pointsLabel.topAnchor.constraint(equalTo: lineView.bottomAnchor, constant: 12.0),
                pointsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                
                bottomLabel.heightAnchor.constraint(equalToConstant: 26.0),
                bottomLabel.topAnchor.constraint(equalTo: pointsLabel.bottomAnchor, constant: 1.0),
                bottomLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
                bottomLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            ].forEach { $0.isActive = true }
            
        case .notExists:
            vertical = 17.0
            resultLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical).isActive = true
        }
        
        [
            widthAnchor.constraint(equalToConstant: 246.0),
            
            topLabel.heightAnchor.constraint(equalToConstant: 26.0),
            topLabel.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            topLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            resultLabel.heightAnchor.constraint(equalToConstant: 31.0),
            resultLabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: 1.0),
            resultLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ].forEach { $0.isActive = true }
    }
}

fileprivate extension UIFont {
    class func futura(size: CGFloat) -> UIFont {
        return UIFont(name: "Futura-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
}

fileprivate extension UIColor {
    class var grayLabel: UIColor {
        return UIColor(hex: "9B9B9B", alpha: 0.7)!
    }
    
    class var greenLabel: UIColor {
        return UIColor(hex: "77C919")!
    }
    
    class var blueLabel: UIColor {
        return UIColor(hex: "299DD9")!
    }
    
    class var redLabel: UIColor {
        return UIColor(hex: "D65867")!
    }
}

fileprivate extension CALayer {
    func applySketchShadow(color: UIColor = .black, alpha: Float = 0.5, x: CGFloat = 0, y: CGFloat = 2, blur: CGFloat = 4, spread: CGFloat = 0) {
        shadowColor = color.cgColor
        shadowOpacity = alpha
        shadowOffset = CGSize(width: x, height: y)
        shadowRadius = blur / (2.0 * UIScreen.main.scale)
        if spread == 0 {
            shadowPath = nil
        } else {
            let dx = -spread / UIScreen.main.scale
            let rect = bounds.insetBy(dx: dx, dy: dx)
            shadowPath = UIBezierPath(rect: rect).cgPath
        }
    }
}
