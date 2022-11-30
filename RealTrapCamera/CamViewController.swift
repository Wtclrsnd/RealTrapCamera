//
//  ViewController.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 06.09.2022.
//

import UIKit
import AVFoundation

final class CamViewController: UIViewController {

    private lazy var bottomBar = BottomBarView()
    private lazy var topBar = TopBarView()

    private var captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var captureDevice: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
                                                                        [.builtInTripleCamera,.builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
                                                                    mediaType: .video,
                                                                    position: .back)

    private var backInput: AVCaptureInput!
    private var frontInput: AVCaptureInput!
    private let cameraQueue = DispatchQueue(label: "com.shpeklord.CapturingModelQueue")
    private var previewLayer: AVCaptureVideoPreviewLayer!

    private var startZoom: CGFloat = 2.0
    private let zoomLimit: CGFloat = 10.0

    private var takePicture = false
    private var backCameraOn = true

    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermissions()
        setupAndStartCaptureSession()
        setUpZoomRecognizer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

// MARK: - UI
    private func setUpUI() {

        view.addSubview(topBar)
        view.addSubview(bottomBar)

        topBar.delegate = self
        bottomBar.delegate = self

        bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.23).isActive = true

        topBar.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        topBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.14).isActive = true
    }

    private func setUpZoomRecognizer() {
        let zoomRecognizer = UIPinchGestureRecognizer()
        zoomRecognizer.addTarget(self, action: #selector(didPinch(_:)))
        view.addGestureRecognizer(zoomRecognizer)
    }

// MARK: - captureSession: outputs and inputs
    private func currentDevice() -> AVCaptureDevice? {
        let devices = discoverySession.devices
        if devices.isEmpty {
            fatalError("No Camera")
        }
        let device = devices.first
        if device?.deviceType == .builtInDualCamera || device?.deviceType == .builtInWideAngleCamera {
            startZoom = 1.0
        }
        return device
    }

    private func setUpPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) as AVCaptureVideoPreviewLayer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    private func setupAndStartCaptureSession(){
        cameraQueue.async {
            self.captureSession.beginConfiguration()

            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true

            self.setupInputs()

            DispatchQueue.main.async {
                self.setUpPreviewLayer()
                self.setUpUI()
            }

            self.setupOutput()

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    private func setupInputs() {
        backCamera = currentDevice()
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        guard let backCamera = backCamera, let frontCamera = frontCamera else {
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
        videoOutput.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(videoOutput)
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.connections.first?.videoOrientation = .portrait
    }

    private func switchCameraInput() {
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            captureDevice = frontCamera
            backCameraOn = false
            topBar.flashButton.isHidden = true
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            captureDevice = backCamera
            backCameraOn = true
            topBar.flashButton.isHidden = false
            updateZoom(scale: startZoom)
        }

        videoOutput.connections.first?.videoOrientation = .portrait
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn
        captureSession.commitConfiguration()
    }
}

// MARK: - Bottom bar delegate
extension CamViewController: BottomBarDelegate {
    func switchCamera() {
        switchCameraInput()
    }

    func takePhoto() {
        takePicture = true
    }


}

// MARK: - Top bar delegate
extension CamViewController: TopBarDelegate {
    func switchFlash(torch: Bool) {
        toggleTorch(on: torch)
    }

}

// MARK: - zoom options
extension CamViewController {

    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .changed {
            setZoom(scale: recognizer.scale)
        }
    }

    private func minMaxZoom(_ factor: CGFloat) -> CGFloat { return min(max(factor, 1.0), zoomLimit) }

    private func updateZoom(scale: CGFloat) {
        do {
            try captureDevice?.lockForConfiguration()
            defer { captureDevice?.unlockForConfiguration() }
                captureDevice?.videoZoomFactor = scale
        } catch {
            print(error.localizedDescription)
        }
    }

    func setZoom(scale: CGFloat) {
        guard let zoomFactor = captureDevice?.videoZoomFactor else {
            return
        }
        var newScaleFactor: CGFloat = 0
        if scale < 1.0 {
            newScaleFactor = zoomFactor - pow(zoomLimit, 1.0 - scale)
        }
        else {
            newScaleFactor = zoomFactor + pow(zoomLimit, (scale - 1.0) / 2.0)
        }
        newScaleFactor = minMaxZoom(zoomFactor * scale)
        updateZoom(scale: newScaleFactor)
    }

    func toggleTorch(on: Bool) {
        guard let captureDevice = captureDevice else {
            return
        }

        if captureDevice.hasTorch {
            do {
                try captureDevice.lockForConfiguration()

                if on == true {
                    captureDevice.torchMode = .on
                } else {
                    captureDevice.torchMode = .off
                }

                captureDevice.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
}

// MARK: - checking permision
extension CamViewController {
    private func checkPermissions() {
        let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch cameraAuthStatus {
        case .authorized:
            return
        case .denied:
            abort()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
                                            { (authorized) in
                if(!authorized){
                    abort()
                }
            })
        case .restricted:
            abort()
        @unknown default:
            fatalError()
        }
    }
}

// MARK: - handling shots
extension CamViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !takePicture {
            return
        }
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        let uiImage = UIImage(ciImage: ciImage)
        ImageSaver.writeToPhotoAlbum(image: uiImage)

        DispatchQueue.main.async {
            self.bottomBar.setUpPhoto(image: uiImage)
            self.takePicture = false
        }
    }
}

