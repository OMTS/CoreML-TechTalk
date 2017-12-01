//
//  GodModeViewController.swift
//  CheersDemo
//
//  Created by Iman Zarrabian on 29/11/2017.
//  Copyright © 2017 Iman Zarrabian. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class GodModeViewController: UIViewController {

    @IBOutlet weak var godView: UIView!
    @IBOutlet weak var detectionLabel: UILabel!
    @IBOutlet weak var highlightView: UIView? {
        didSet {
            self.highlightView?.layer.borderColor = UIColor.green.cgColor
            self.highlightView?.layer.borderWidth = 4
            self.highlightView?.backgroundColor = .clear
        }
    }
    var session = AVCaptureSession()
    var requests =  [VNRequest]()
    let faceBoxLayer = CALayer()
    var imageLayer: AVCaptureVideoPreviewLayer!
    var stillImageOutput: AVCapturePhotoOutput?
    var captureDevice: AVCaptureDevice!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.focus(tapGesture:)))
        godView.addGestureRecognizer(tapGesture)
        
        startVideoStreeam()
    }
    
    @objc func focus(tapGesture: UITapGestureRecognizer) {
        let pointTapped = tapGesture.location(in: godView)
        let convertedPoint = imageLayer.captureDevicePointConverted(fromLayerPoint: pointTapped)
        try? captureDevice.lockForConfiguration()
        if captureDevice.isExposurePointOfInterestSupported {
            captureDevice.exposurePointOfInterest = convertedPoint
            captureDevice.exposureMode = .autoExpose
        }
        captureDevice.unlockForConfiguration()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //Classification
        if let mlRequest = classificationRequest(from: .vgg16) {
            requests.append(mlRequest)
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVideoStream()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        godView.layer.sublayers?[0].frame = godView.bounds
    }
    
    func classificationRequest(from model: ClassificationType) -> VNCoreMLRequest? {
        switch model {
        case .inceptionV3:
            let mobileNet = Inceptionv3()
            if let model = try? VNCoreMLModel(for: mobileNet.model) {
                let mlRequest = VNCoreMLRequest(model: model, completionHandler: classificationHandler)
                return mlRequest
            }
        case .mobileNet:
            let mobileNet = MobileNet()
            if let model = try? VNCoreMLModel(for: mobileNet.model) {
                let mlRequest = VNCoreMLRequest(model: model, completionHandler: classificationHandler)
                return mlRequest
            }
        case .vgg16:
            let vgg = VGG16()
            if let model = try? VNCoreMLModel(for: vgg.model) {
                let mlRequest = VNCoreMLRequest(model: model, completionHandler: classificationHandler)
                return mlRequest
            }
        }
        
        return nil
    }

    func startVideoStreeam() {
        session.sessionPreset = AVCaptureSession.Preset.photo
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        try? captureDevice.lockForConfiguration()
        captureDevice.exposureMode = .autoExpose
        captureDevice.unlockForConfiguration()
        
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        session.addInput(deviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        session.addOutput(videoOutput)
        
        
        imageLayer = AVCaptureVideoPreviewLayer(session: session)
        godView.frame = godView.bounds
        godView.layer.addSublayer(imageLayer)
        
        session.startRunning()
    }

    func stopVideoStream() {
        session.stopRunning()
    }

    
    func classificationHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            print("oooops! didn't provide classification observations")
            return
        }
        guard let bestResult = observations.first else {
            print("oooops! invalid classification")
            return
        }
        
        updateDetectionLabel(observation: bestResult)
    }
    
    func updateDetectionLabel(observation: VNClassificationObservation) {
        DispatchQueue.main.async {
            self.detectionLabel.text = observation.identifier + " à \(observation.confidence*100)%"
        }
    }

}

//AVCaptureVideoDataOutputSampleBufferDelegate colmpliance
extension GodModeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions: [VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: camData]
        }
        
        //classification request
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: requestOptions)
        do {
            try imageRequestHandler.perform(requests) //classification request
        } catch {
            print(error)
        }
    }
}
