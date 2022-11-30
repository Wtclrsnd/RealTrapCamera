//
//  CaptureImageButton.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 07.10.2022.
//

import UIKit

final class CaptureImageButton: UIButton {

    override var intrinsicContentSize: CGSize {
        CGSize(width: 72, height: 72)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = intrinsicContentSize.height / 2
        layer.borderWidth = 4
        layer.borderColor = UIColor.lavanda.cgColor
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIColor {

    static var lavanda: UIColor {
        return UIColor(red: 0.605, green: 0.407, blue: 0.929, alpha: 1)
    }
}
