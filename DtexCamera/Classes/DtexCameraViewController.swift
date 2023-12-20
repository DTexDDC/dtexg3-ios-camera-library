//
//  DtexCameraViewController.swift
//  DtexCamera
//
//  Created by Admin on 12/1/23.
//

import UIKit
import AVFoundation
import Foundation
import Vision
import TensorFlowLite
import Accelerate
import CoreMotion

public protocol DtexCameraViewControllerDelegate: class {
    func dtexCamera(_ dtexCamera: DtexCameraViewController, didTake photo: UIImage)
}

open class DtexCameraViewController: UIViewController {
    
    private var previewView: UIView!
    private var shutterButton: KYShutterButton!
    private var reviewView: UIView!
    private var stillImageView: UIImageView!
    private var canvasImageView: UIImageView!
    private var rotationLabel: UILabel!
    
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice!
    private var stillImage: UIImage?
    private var stillImageOutput: AVCapturePhotoOutput!
    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: DispatchQueue!
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let context = CIContext()
    
    private let inputSize = 512
    private var modelInterpreter: Interpreter?
    
    public var modelPath: String?
    public weak var delegate: DtexCameraViewControllerDelegate?
    
    private let motionManager: CMMotionManager = {
        let manager = CMMotionManager()
        manager.deviceMotionUpdateInterval = 0.1
        return manager
    }()
    private var rotation: Double = 0.0

    open override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupPreviewLayer()
        configureModel()
        
        checkPermission()
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraPreviewLayer?.frame = previewView.bounds
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async {
            guard self.permissionGranted else { return }
            self.captureSession.startRunning()
        }
        motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            // Handle device motion updates
            guard let motion else { return }
            let attitude = motion.attitude
            self.rotation = attitude.pitch
            self.rotationLabel.text = "Rotation: \(self.rotation)"
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
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
        
        captureSession.beginConfiguration()
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
        
        captureSession.commitConfiguration()
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
    
    private func configureModel() {
        guard modelPath != nil else { return }
        do {
            let interpreter = try Interpreter(modelPath: modelPath!)
            try interpreter.allocateTensors()
            modelInterpreter = interpreter
        } catch {
            print("[DtexCamera]: \(error.localizedDescription)")
        }
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
        
        stillImage = UIImage(data: imageData)
        stillImageView.image = stillImage
        reviewView.isHidden = false
    }
}

extension DtexCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process frame
        guard modelInterpreter != nil else {
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        do {
            let inputTensor = try modelInterpreter!.input(at: 0)
            
            // Crops the image to the biggest square in the center and scales it down to model dimensions.
            let scaledSize = CGSize(width: inputSize, height: inputSize)
            guard let scaledPixelBuffer = imageBuffer.resized(to: scaledSize) else {
                return
            }
            
            guard let inputData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: 1 * inputSize * inputSize * 3,
                isModelQuantized: inputTensor.dataType == .uInt8
            ) else {
                print("[DtexCamera]: Failed to convert image buffer to RGB data")
                return
            }
            
            // Copy RGB data to input `Tensor`
            try modelInterpreter!.copy(inputData, toInputAt: 0)
            try modelInterpreter!.invoke()
            let confidenceOutput = try modelInterpreter!.output(at: 0)
            let locationsOutput = try modelInterpreter!.output(at: 1)
            // let detectionCountOutput = try modelInterpreter!.output(at: 2)
            // let categoriesOutput = try modelInterpreter!.output(at: 3)
            
            let scores = [Float32](unsafeData: confidenceOutput.data) ?? []
            let boundingBoxes = processBoundingBoxes(input: [Float32](unsafeData: locationsOutput.data) ?? [])
            //let detectionCount = [Float32](unsafeData: detectionCountOutput.data) ?? []
            //let categories = [Float32](unsafeData: categoriesOutput.data) ?? []
            
            let sortedScores = scores.enumerated().sorted(by: { $0.element > $1.element }).filter{ $0.element > 0.1 }
            let indices = sortedScores.map{ $0.offset }
            let previewWidth = UIScreen.main.bounds.width
            let previewHeight = previewWidth * 3 / 4
            DispatchQueue.main.async {
                self.canvasImageView.image = nil
                let renderer = UIGraphicsImageRenderer(size: self.canvasImageView.bounds.size)
                let image = renderer.image { ctx in
                    ctx.cgContext.setStrokeColor(UIColor.systemGreen.cgColor)
                    ctx.cgContext.setLineWidth(3)
                    
                    for index in indices[0..<min(5, indices.count)] {
                        let xmin = CGFloat(boundingBoxes[index]["xmin"]!) * previewWidth
                        let ymin = CGFloat(boundingBoxes[index]["ymin"]!) * previewHeight
                        let xmax = CGFloat(boundingBoxes[index]["xmax"]!) * previewWidth
                        let ymax = CGFloat(boundingBoxes[index]["ymax"]!) * previewHeight
                        
                        ctx.cgContext.move(to: CGPoint(x: xmin, y: ymin))
                        ctx.cgContext.addLine(to: CGPoint(x: xmax, y: ymin))
                        ctx.cgContext.addLine(to: CGPoint(x: xmax, y: ymax))
                        ctx.cgContext.addLine(to: CGPoint(x: xmin, y: ymax))
                        ctx.cgContext.addLine(to: CGPoint(x: xmin, y: ymin))
                        
                        ctx.cgContext.drawPath(using: .stroke)
                    }
                }
                self.canvasImageView.image = image
            }
        } catch {
            print("[DtexCamera]: \(error.localizedDescription)")
        }
    }
    
    private func processBoundingBoxes(input: [Float32]) -> [Dictionary<String, Float32>] {
        let flatBBs = input.chunked(by: 4)
        var out: [Dictionary<String, Float32>] = []
        for flatBB in flatBBs {
            out.append([
                "ymin": flatBB[0],
                "xmin": flatBB[1],
                "ymax": flatBB[2],
                "xmax": flatBB[3]
            ])
        }
        return out
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
        previewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        previewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        previewView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: 0).isActive = true
        NSLayoutConstraint(item: previewView, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: previewView, attribute: NSLayoutConstraint.Attribute.width, multiplier: 4/3, constant: 0).isActive = true
        
        // Canvas ImageView
        canvasImageView = UIImageView()
        view.addSubview(canvasImageView)
        canvasImageView.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        rotationLabel = UILabel()
        view.addSubview(rotationLabel)
        rotationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            canvasImageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            canvasImageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            canvasImageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            canvasImageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            
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
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            
            rotationLabel.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 20),
            rotationLabel.topAnchor.constraint(equalTo: previewView.topAnchor, constant: 20)
        ])
        reviewView.isHidden = true
    }
    
    @objc func retakeTapped(sender: UIButton) {
        reviewView.isHidden = true
    }
    
    @objc func doneTapped(sender: UIButton) {
        if let image = stillImage {
            delegate?.dtexCamera(self, didTake: image)
        }
        navigationController?.popViewController(animated: true)
    }
}
