//
//  ViewController.swift
//  CheersDemo
//
//  Created by Iman Zarrabian on 21/11/2017.
//  Copyright © 2017 Iman Zarrabian. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import ImageIO

class CameraViewController: UIViewController {

    @IBOutlet weak var validateButton: UIButton!
    @IBOutlet weak var liveView: UIView!
    @IBOutlet weak var faceLabel: UILabel!
    @IBOutlet weak var drinkLabel: UILabel!
    
    var session = AVCaptureSession()
    var requests =  [VNRequest]()
    let faceBoxLayer = CALayer()
    var imageLayer: AVCaptureVideoPreviewLayer!
    var stillImageOutput: AVCapturePhotoOutput?
    var captureDevice: AVCaptureDevice!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                 options: NSKeyValueObservingOptions.new, context: nil)
        
        faceLabel.text = "No face detected 😰"
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.focus(tapGesture:)))
        liveView.addGestureRecognizer(tapGesture)
        startVideoStreeam()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume"{
            capturePhoto(UIBarButtonItem())
        }
    }
    
    
    @objc func focus(tapGesture: UITapGestureRecognizer) {
        let pointTapped = tapGesture.location(in: liveView)
        let convertedPoint = imageLayer.captureDevicePointConverted(fromLayerPoint: pointTapped)
        try? captureDevice.lockForConfiguration()
        if captureDevice.isExposurePointOfInterestSupported {
            captureDevice.exposurePointOfInterest = convertedPoint
            captureDevice.exposureMode = .autoExpose
        }
        captureDevice.unlockForConfiguration()
    }
    
    @IBAction func capturePhoto(_ sender: UIBarButtonItem) {
        guard let captureOutput = stillImageOutput else {
            return
        }
        captureOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session.startRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //Face Detection
        let faceRequest = VNDetectFaceLandmarksRequest(completionHandler: faceHandler)
        requests = [faceRequest]
        
        //Classification
        if let mlRequest = classificationRequest(from: .vgg16) {
            requests.append(mlRequest)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVideoStream()
    }
    
    func classificationRequest(from model: ClassificationType) -> VNCoreMLRequest? {
        switch model {
        case .inceptionV3:
            let inception = Inceptionv3()
            if let model = try? VNCoreMLModel(for: inception.model) {
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
    
    override func viewDidLayoutSubviews() {
        liveView.layer.sublayers?[0].frame = liveView.bounds
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "StillImageViewControllerSegue",
            let destVC = segue.destination as? StillImageViewController, let image = sender as? UIImage {
            destVC.capturedPhoto = image
        }
    }
    
    func startVideoStreeam() {
        session.sessionPreset = AVCaptureSession.Preset.photo
        captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
        try? captureDevice.lockForConfiguration()
        captureDevice.exposureMode = .autoExpose
        captureDevice.unlockForConfiguration()
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        
        let deviceOutput = AVCaptureVideoDataOutput()
        stillImageOutput = AVCapturePhotoOutput()

        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        session.addOutput(stillImageOutput!)

        imageLayer = AVCaptureVideoPreviewLayer(session: session)
        liveView.frame = liveView.bounds
        liveView.layer.addSublayer(imageLayer)
        
        session.startRunning()
    }

    func stopVideoStream() {
        session.stopRunning()
    }
}

//AVCaptureVideoDataOutputSampleBufferDelegate colmpliance
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions: [VNImageOption : Any] = [:]

        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: requestOptions)
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        guard let cgImgRef = photo.cgImageRepresentation() else {
            return
        }
        let cgImage = cgImgRef.takeUnretainedValue()
        
       // let image = UIImage(cgImage: cgImage)
        let image  = UIImage(cgImage:cgImage, scale:1.0, orientation:.right)

        performSegue(withIdentifier: "StillImageViewControllerSegue", sender: image)
    }
}

//Vision Handlers
extension CameraViewController {
    func faceHandler(request: VNRequest, error: Error?) {

        guard let observations = request.results as? [VNFaceObservation] else {
            print("oooops! didn't provide faces observations")
            return
        }
        DispatchQueue.main.async {
            self.drawFaceBox(observations: observations)
        }
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
        
        updateDrinkLabel(observation: bestResult)
        
    }
}

//methods for updating UI
extension CameraViewController {
    func drawFaceBox(observations: [VNFaceObservation]) {

        for o in observations {
            //https://github.com/jeffreybergier/Blog-Getting-Started-with-Vision/issues/2
            let vnBox = o.boundingBox
            print(String(format: "-> VN box | x:%.01f y:%.01f w:%.01f h:%.01f", vnBox.origin.x, vnBox.origin.y, vnBox.width, vnBox.height))
            
            let avBox = CGRect(x: 1 - (vnBox.origin.y + vnBox.width), y: 1 - (vnBox.origin.x + vnBox.height), width: vnBox.width, height: vnBox.height)
            print(String(format: "-> AV box | x:%.01f y:%.01f w:%.01f h:%.01f", avBox.origin.x, avBox.origin.y, avBox.width, avBox.height))
            
            let uiBox = imageLayer.layerRectConverted(fromMetadataOutputRect: avBox)
            print(String(format: "-> UI box | x:%.01f y:%.01f w:%.01f h:%.01f", uiBox.origin.x, uiBox.origin.y, uiBox.width, uiBox.height))
            
            faceBoxLayer.removeFromSuperlayer()
            faceBoxLayer.frame = uiBox
            faceBoxLayer.borderWidth = 1.0
            faceBoxLayer.borderColor = UIColor.green.cgColor
            
            liveView.layer.addSublayer(faceBoxLayer)
        }
        if observations.count == 0 {
            faceBoxLayer.borderColor = UIColor.red.cgColor
            faceLabel.text = "No face detected 😰"
        } else {
            faceLabel.text = "Hi dude 😎"
        }
    }
    
    
    func updateDrinkLabel(observation: VNClassificationObservation) {
        DispatchQueue.main.async {
            let scene = ObjectType(classification: observation.identifier)
            var drinkEmoji: String?
            
            switch scene {
            case .coffee:
                drinkEmoji = "☕️"
            case .beer:
                drinkEmoji = "🍺"
            case .glass:
                drinkEmoji = "🥛"
            case .wine:
                drinkEmoji = "🍷"
            default:
                break
            }
            
            if let drinkEmoji = drinkEmoji {
                self.drinkLabel.text = "have a nice " + drinkEmoji
            } else {
                self.drinkLabel.text = ""
            }
        }
    }
}

