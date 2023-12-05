//
//  DtexCameraViewController.swift
//  DtexCamera
//
//  Created by Admin on 12/1/23.
//

import UIKit
import AVFoundation

open class DtexCameraViewController: UIViewController {
    
    let captureSession = AVCaptureSession()
    var stillImageOutput: AVCapturePhotoOutput!
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?

    open override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    private func configure() {
        // Preset the session for taking photo in full resolution
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        // Get the back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            return
        }
        
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: backCamera) else {
            return
        }
        
        // Configure the session with the output for capturing still images
        stillImageOutput = AVCapturePhotoOutput()
        
        // Configure the session with the input and the output devices
        captureSession.addInput(captureDeviceInput)
        captureSession.addOutput(stillImageOutput)
        
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
