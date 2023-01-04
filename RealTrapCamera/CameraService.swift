//
//  CameraService.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 07.12.2022.
//

import UIKit
import AVFoundation

protocol CameraServiceDelegate: AnyObject {

    func setPhoto(image: UIImage)
    func toggleIsHiddenFlashButton()
}

final class CameraService: NSObject {

    private var captureDevice: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?

    private var backInput: AVCaptureInput!
    private var frontInput: AVCaptureInput!
    private let cameraQueue = DispatchQueue(label: "com.shpeklord.CapturingModelQueue")

    private var startZoom: CGFloat = 2.0
    private let zoomLimit: CGFloat = 10.0

    private var backCameraOn = true

    weak var delegate: CameraServiceDelegate?

    var captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()

    override init() {
        super.init()
        setupAndStartCaptureSession()
    }

    func setZoom(scale: CGFloat) {
        guard let zoomFactor = captureDevice?.videoZoomFactor else {
            return
        }
        var newScaleFactor: CGFloat = 0

        newScaleFactor = (scale < 1.0
        ? (zoomFactor - pow(zoomLimit, 1.0 - scale))
        : (zoomFactor + pow(zoomLimit, (scale - 1.0) / 2.0)))

        newScaleFactor = minMaxZoom(zoomFactor * scale)
        updateZoom(scale: newScaleFactor)
    }

    func switchCameraInput() {
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            captureDevice = frontCamera
            backCameraOn = false
            delegate?.toggleIsHiddenFlashButton()
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            captureDevice = backCamera
            backCameraOn = true
            delegate?.toggleIsHiddenFlashButton()
            updateZoom(scale: startZoom)
        }

        photoOutput.connections.first?.videoOrientation = .portrait
        photoOutput.connections.first?.isVideoMirrored = !backCameraOn
        captureSession.commitConfiguration()
    }

    private func currentDevice() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
                                                                    [.builtInTripleCamera,.builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
                                                                mediaType: .video,
                                                                position: .back)
        guard let device = discoverySession.devices.first
        else {
            return nil
        }

        if device.deviceType == .builtInDualCamera || device.deviceType == .builtInWideAngleCamera {
            startZoom = 1.0
        }
        return device
    }

    private func setupAndStartCaptureSession() {
        cameraQueue.async { [weak self] in
            self?.captureSession.beginConfiguration()

            if let canSetSessionPreset = self?.captureSession.canSetSessionPreset(.photo), canSetSessionPreset {
                self?.captureSession.sessionPreset = .photo
            }
            self?.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true

            self?.setupInputs()
            self?.setupOutput()

            self?.captureSession.commitConfiguration()
            self?.captureSession.startRunning()
        }
    }

    private func setupInputs() {
        backCamera = currentDevice()
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        guard let backCamera = backCamera,
              let frontCamera = frontCamera
        else {
            return
        }

        do {
            backInput = try AVCaptureDeviceInput(device: backCamera)
            guard captureSession.canAddInput(backInput) else {
                return
            }

            frontInput = try AVCaptureDeviceInput(device: frontCamera)
            guard captureSession.canAddInput(frontInput) else {
                return
            }
        } catch {
            fatalError("could not connect camera")
        }

        captureDevice = backCamera

        captureSession.addInput(backInput)

        if backCamera.deviceType == .builtInDualWideCamera || backCamera.deviceType == .builtInTripleCamera {
            updateZoom(scale: startZoom)
        }
    }

    private func setupOutput() {
        guard captureSession.canAddOutput(photoOutput) else {
            return
        }

        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .balanced

        captureSession.addOutput(photoOutput)
    }

    private func minMaxZoom(_ factor: CGFloat) -> CGFloat { min(max(factor, 1.0), zoomLimit) }

    private func updateZoom(scale: CGFloat) {
        do {
            defer { captureDevice?.unlockForConfiguration() }
            try captureDevice?.lockForConfiguration()
            captureDevice?.videoZoomFactor = scale
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Fail to capture photo: \(String(describing: error))")
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        guard let image = UIImage(data: imageData) else {
            return
        }

        DispatchQueue.main.async {
            self.delegate?.setPhoto(image: image)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}
