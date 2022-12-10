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

    private let videoOutput = AVCaptureVideoDataOutput()
    private var captureDevice: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?

    private var backInput: AVCaptureInput!
    private var frontInput: AVCaptureInput!
    private let cameraQueue = DispatchQueue(label: "com.shpeklord.CapturingModelQueue")

    private var startZoom: CGFloat = 2.0
    private let zoomLimit: CGFloat = 10.0

    private var backCameraOn = true

    var takePicture = false

    weak var delegate: CameraServiceDelegate?

    var captureSession = AVCaptureSession()

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

    func toggleTorch(on: Bool) {
        guard let captureDevice = captureDevice else {
            return
        }

        if captureDevice.hasTorch {
            tryToggleTorch(on: on)
        } else {
            print("Torch is not available")
        }
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
        cameraQueue.async {
            self.captureSession.beginConfiguration()

            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true // to watch

            self.setupInputs()
            self.setupOutput()

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
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
        guard captureSession.canAddOutput(videoOutput) else {
            return
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true // todo
        captureSession.addOutput(videoOutput)
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.connections.first?.videoOrientation = .portrait
    }

    func switchCameraInput() { // to move
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

        videoOutput.connections.first?.videoOrientation = .portrait
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn
        captureSession.commitConfiguration()
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

    private func tryToggleTorch(on: Bool) {
        do {
            try captureDevice?.lockForConfiguration()

            captureDevice?.torchMode = on
            ? .on
            : .off

            captureDevice?.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), takePicture == true else {
            return
        }
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        let uiImage = UIImage(ciImage: ciImage)

        DispatchQueue.main.async {
            self.delegate?.setPhoto(image: uiImage)
            self.takePicture = false
        }
    }
}
