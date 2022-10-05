//
//  ViewController.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 06.09.2022.
//

import UIKit
import AVFoundation

class CamViewController: UIViewController {

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
    private let zoomLimit: CGFloat = 5.0

    private var takePicture = false
    private var backCameraOn = true
    private var lastViewIsHidden = true {
        didSet {
            lastPhotoView.isHidden = lastViewIsHidden
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupAndStartCaptureSession()
        setUpZoomRecognizer()
    }

    private func setUpUI() {
        view.addSubview(captureImageButton)
        view.addSubview(lastPhotoView)
        view.addSubview(switchCameraButton)
        lastPhotoView.isHidden = true

        captureImageButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera(_:)), for: .touchUpInside)

        captureImageButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        captureImageButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        captureImageButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        captureImageButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

        switchCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        switchCameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        switchCameraButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        switchCameraButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        lastPhotoView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        lastPhotoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        lastPhotoView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25).isActive = true
        lastPhotoView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25).isActive = true
    }

    private func setUpZoomRecognizer() {
        let zoomRecognizer = UIPinchGestureRecognizer()
        zoomRecognizer.addTarget(self, action: #selector(didPinch(_:)))
        view.addGestureRecognizer(zoomRecognizer)
    }

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
            updateZoom(scale: startZoom, smoothly: false)
        }
    }

    private func switchCameraInput(){
        //don't let user spam the button, fun for the user, not fun for performance
        switchCameraButton.isUserInteractionEnabled = false

        //reconfigure the input
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
            updateZoom(scale: startZoom, smoothly: false)
        }

        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait

        //mirror the video stream for front camera
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn

        //commit config
        captureSession.commitConfiguration()

        //acitvate the camera button again
        switchCameraButton.isUserInteractionEnabled = true
    }

    private func setupOutput(){
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("could not add video output")
        }

        videoOutput.connections.first?.videoOrientation = .portrait
    }

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

    private func minMaxZoom(_ factor: CGFloat) -> CGFloat { return min(max(factor, 1.0), zoomLimit) }


    @objc private func captureImage(_ sender: UIButton?){
        takePicture = true
        lastViewIsHidden = false
    }

    @objc func switchCamera(_ sender: UIButton?){
        switchCameraInput()
    }

    @objc func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .changed {
            setZoom(scale: recognizer.scale, smoothly: false)
        }
    }

    private func updateZoom(scale: CGFloat, smoothly: Bool) {
        do {
            try captureDevice?.lockForConfiguration()
            defer { captureDevice?.unlockForConfiguration() }
            if smoothly {
                captureDevice?.ramp(toVideoZoomFactor: scale, withRate: 5)
            } else {
                captureDevice?.videoZoomFactor = scale
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func setZoom(scale: CGFloat, smoothly: Bool) {
        guard let zoomFactor = captureDevice?.videoZoomFactor else {
            return
        }
        var newScaleFactor: CGFloat = 0

        if smoothly {
            newScaleFactor = scale
        } else {
            if scale >= 1.0 {
                newScaleFactor = zoomFactor + (scale / 50)
            } else {
                newScaleFactor = zoomFactor - ((scale + 1) / 50)
            }
            newScaleFactor = minMaxZoom(newScaleFactor)
        }
        updateZoom(scale: newScaleFactor, smoothly: smoothly)
    }

}

extension CamViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !takePicture {
            return //we have nothing to do with the image buffer
        }

        //try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)

        //get UIImage out of CIImage
        let uiImage = UIImage(ciImage: ciImage)

        DispatchQueue.main.async {
            self.lastPhotoView.image = uiImage
            self.takePicture = false
        }
    }
}
