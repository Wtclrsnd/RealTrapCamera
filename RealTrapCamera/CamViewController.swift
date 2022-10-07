//
//  ViewController.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 06.09.2022.
//

import UIKit
import AVFoundation

class CamViewController: UIViewController {

    private lazy var bottomBar = BottomBarView()

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupAndStartCaptureSession()
        setUpZoomRecognizer()
    }

// MARK: - UI
    private func setUpUI() {

        view.addSubview(bottomBar)

        bottomBar.delegate = self

        bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.23).isActive = true
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
            //init session
            //start configuration
            self.captureSession.beginConfiguration()

            //session specific configuration
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true

            //setup inputs
            self.setupInputs()

            DispatchQueue.main.async {
                //setup preview layer
                self.setUpPreviewLayer()
                self.setUpUI()
            }

            //setup output
            self.setupOutput()

            //commit configuration
            self.captureSession.commitConfiguration()
            //start running it
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
    }

    private func switchCameraInput() {
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            captureDevice = frontCamera
            backCameraOn = false
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            captureDevice = backCamera
            backCameraOn = true
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
        var newScaleFactor: CGFloat = minMaxZoom(zoomFactor * scale)
        updateZoom(scale: newScaleFactor)
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

        DispatchQueue.main.async {
            self.bottomBar.setUpPhoto(image: uiImage)
            self.takePicture = false
        }
    }
}