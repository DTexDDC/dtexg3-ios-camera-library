//
//  DtexCameraViewController.swift
//  DtexCamera
//
//  Created by Admin on 12/1/23.
//

import UIKit
import AVFoundation

open class DtexCameraViewController: UIViewController {
    
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
        checkPermission()
        sessionQueue.async {
            self.configureSession()
            self.captureSession.startRunning()
        }
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
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutputQueue = DispatchQueue(label: "video output queue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        let outputSettings: [String: Any] = [String(describing: kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoDataOutput.videoSettings = outputSettings
        videoDataOutput.connection(with: .video)?.isEnabled = true
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("[DtexCamera]: Could not add video data output")
            return
        }
        captureSession.addOutput(videoDataOutput)
        
        // Provide a camera preview
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(cameraPreviewLayer!)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.frame = view.layer.frame
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
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
    private func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        
        // Get the image from the photo buffer
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        let stillImage = UIImage(data: imageData)
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
