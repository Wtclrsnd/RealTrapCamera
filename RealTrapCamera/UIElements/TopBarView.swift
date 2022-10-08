//
//  TopBarView.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 08.10.2022.
//

import UIKit

class TopBarView: UIView {

    weak var delegate: BottomBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: .zero)

        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .black.withAlphaComponent(0.5)
    }
}
