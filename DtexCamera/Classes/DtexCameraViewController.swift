//
//  DtexCameraViewController.swift
//  DtexCamera
//
//  Created by Admin on 12/1/23.
//

import UIKit
import AVFoundation

open class DtexCameraViewController: UIViewController {
    
    private var previewView: UIView!
    private var shutterButton: KYShutterButton!
    private var reviewView: UIView!
    private var stillImageView: UIImageView!
    
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: DispatchQueue!
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let context = CIContext()

    open override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        checkPermission()
//        DispatchQueue.global(qos: .userInitiated).async {
            self.configureSession()
//        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraPreviewLayer?.frame = previewView.bounds
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        guard permissionGranted else { return }
        // Preset the session for taking photo in full resolution
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        // Get the back camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            return
        }
        captureDevice = device
        
        // Configure capture device input
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        guard captureSession.canAddInput(captureDeviceInput) else {
            print("[DtexCamera]: Could not add video device input")
            return
        }
        captureSession.addInput(captureDeviceInput)
        
        // Configure the session with the output for capturing still images
        stillImageOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(stillImageOutput) else {
            print("[DtexCamera]: Could not add capture photo output")
            return
        }
        captureSession.addOutput(stillImageOutput)
        
        // Configure video data output
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = false
        videoDataOutputQueue = DispatchQueue(label: "video output queue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        let outputSettings: [String: Any] = [String(describing: kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoDataOutput.videoSettings = outputSettings
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("[DtexCamera]: Could not add video data output")
            return
        }
        captureSession.addOutput(videoDataOutput)
        
        // Provide a camera preview
//        DispatchQueue.main.async {
            self.setupPreviewLayer()
//        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupPreviewLayer() {
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewView.layer.addSublayer(cameraPreviewLayer!)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
    }
    
    @objc func takePhoto(sender: UIButton) {
        // Set photo settings
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        
        stillImageOutput.isHighResolutionCaptureEnabled = true
        stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
    }

}

extension DtexCameraViewController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        
        // Get the image from the photo buffer
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        stillImageView.image = UIImage(data: imageData)
        reviewView.isHidden = false
    }
}

extension DtexCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process frame
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension DtexCameraViewController {
    private func setupView() {
        view.backgroundColor = .black
        // Preview View
        previewView = UIView()
        view.addSubview(previewView)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0).isActive = true
        NSLayoutConstraint(item: previewView, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: previewView, attribute: NSLayoutConstraint.Attribute.width, multiplier: 4/3, constant: 0).isActive = true
        
        // Shutter Button
        shutterButton = KYShutterButton()
        view.addSubview(shutterButton)
        shutterButton.buttonColor = .white
        shutterButton.setNeedsLayout()
        shutterButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        shutterButton.widthAnchor.constraint(equalToConstant: 75).isActive = true
        shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor, multiplier: 1).isActive = true
        shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        
        // Review View
        reviewView = UIView()
        reviewView.backgroundColor = .black
        view.addSubview(reviewView)
        reviewView.translatesAutoresizingMaskIntoConstraints = false
        
        stillImageView = UIImageView()
        stillImageView.contentMode = .scaleAspectFit
        reviewView.addSubview(stillImageView)
        stillImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonsView = UIView()
        buttonsView.backgroundColor = UIColor(hex: "#141414ff")
        reviewView.addSubview(buttonsView)
        buttonsView.translatesAutoresizingMaskIntoConstraints = false
        
        let retakeButton = UIButton()
        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.setTitleColor(.white, for: .normal)
        retakeButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        buttonsView.addSubview(retakeButton)
        retakeButton.translatesAutoresizingMaskIntoConstraints = false
        
        let doneButton = UIButton()
        doneButton.setTitle("Use Photo", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        buttonsView.addSubview(doneButton)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            reviewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            reviewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            reviewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            reviewView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            stillImageView.leadingAnchor.constraint(equalTo: reviewView.leadingAnchor),
            stillImageView.topAnchor.constraint(equalTo: reviewView.topAnchor),
            stillImageView.trailingAnchor.constraint(equalTo: reviewView.trailingAnchor),
            stillImageView.bottomAnchor.constraint(equalTo: reviewView.bottomAnchor),
            
            buttonsView.leadingAnchor.constraint(equalTo: reviewView.leadingAnchor, constant: 20),
            buttonsView.centerXAnchor.constraint(equalTo: reviewView.centerXAnchor),
            buttonsView.bottomAnchor.constraint(equalTo: reviewView.bottomAnchor, constant: -20),
            buttonsView.heightAnchor.constraint(equalToConstant: 70),
            
            retakeButton.leadingAnchor.constraint(equalTo: buttonsView.leadingAnchor, constant: 8),
            retakeButton.centerYAnchor.constraint(equalTo: buttonsView.centerYAnchor),
            retakeButton.heightAnchor.constraint(equalToConstant: 50),
            
            doneButton.trailingAnchor.constraint(equalTo: buttonsView.trailingAnchor, constant: -8),
            doneButton.centerYAnchor.constraint(equalTo: buttonsView.centerYAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        reviewView.isHidden = true
    }
    
    @objc func retakeTapped(sender: UIButton) {
        reviewView.isHidden = true
    }
    
    @objc func doneTapped(sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}
