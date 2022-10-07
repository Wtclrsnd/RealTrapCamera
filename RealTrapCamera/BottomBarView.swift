//
//  BottomBarView.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 06.10.2022.
//

import UIKit

protocol BottomBarDelegate: AnyObject {
    func switchCamera()
    func takePhoto()
}
class BottomBarView: UIView {

    private lazy var captureImageButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var switchCameraButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .green
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var lastPhotoView = LastPhotoView()

    weak var delegate: BottomBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: .zero)

        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {
        addSubview(captureImageButton)
        addSubview(switchCameraButton)
        addSubview(lastPhotoView)

        backgroundColor = .black.withAlphaComponent(0.5)

        translatesAutoresizingMaskIntoConstraints = false

        captureImageButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        captureImageButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        captureImageButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        captureImageButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

        switchCameraButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20).isActive = true
        switchCameraButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        switchCameraButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        switchCameraButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        lastPhotoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        lastPhotoView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        lastPhotoView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        lastPhotoView.heightAnchor.constraint(equalToConstant: 50).isActive = true

        captureImageButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera(_:)), for: .touchUpInside)
    }

    @objc private func captureImage(_ sender: UIButton?) {
        delegate?.takePhoto()
    }

    @objc private func switchCamera(_ sender: UIButton?) {
        delegate?.switchCamera()
    }

    func setUpPhoto(image: UIImage) {
        lastPhotoView.image = image
    }
}
