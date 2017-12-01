//
//  StillImageViewController.swift
//  CheersDemo
//
//  Created by Iman Zarrabian on 22/11/2017.
//  Copyright © 2017 Iman Zarrabian. All rights reserved.
//

import UIKit
import Vision

class StillImageViewController: UIViewController {

    @IBOutlet weak var capturedPhotoIV: UIImageView!
    @IBOutlet weak var magicSwitch: UISwitch!
    
    var capturedPhoto: UIImage!
    var requests = [VNRequest]()
    override func viewDidLoad() {
        super.viewDidLoad()
        capturedPhotoIV.image = capturedPhoto
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTextDetection()
    }
    
    @IBAction func switched(_ sender: UISwitch) {
        for v in capturedPhotoIV.subviews {
            v.removeFromSuperview()
        }
        if let sublayers = capturedPhotoIV.layer.sublayers {
            for layer in sublayers {
                layer.removeFromSuperlayer()
            }
        }
        startTextDetection()
    }
}

extension StillImageViewController {
    func startTextDetection() {
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: textHandler)
        textRequest.reportCharacterBoxes = true
        requests = [textRequest]
        let handler = VNImageRequestHandler(cgImage: capturedPhotoIV.image!.cgImage!, orientation: .right)
        
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform(self.requests)
            } catch {
                print("Error handling vision request \(error)")
            }
        }
    }
    
    func textHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNTextObservation] else {
            print("oooops! didn't provide text observations")
            return
        }
        
        DispatchQueue.main.async() {
            self.capturedPhotoIV.layer.sublayers?.removeSubrange(1...)
            for region in observations {
                self.highlightWord(box: region)
                
                if let boxes = region.characterBoxes {
                    for characterBox in boxes {
                        self.highlightLetters(box: characterBox)
                    }
                }
            }
        }
    }
}


//drawing boxes extracted from https://www.appcoda.com/vision-framework-introduction/
extension StillImageViewController {
    func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {
            return
        }
        
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX * capturedPhotoIV.frame.size.width
        let yCord = (1 - minY) * capturedPhotoIV.frame.size.height
        let width = (minX - maxX) * capturedPhotoIV.frame.size.width
        let height = (minY - maxY) * capturedPhotoIV.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        let blurEffect: UIBlurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.frame = outline.frame

        if !magicSwitch.isOn {
            capturedPhotoIV.layer.addSublayer(outline)
        } else {
            capturedPhotoIV.addSubview(blurView)
            let vibrancyView: UIVisualEffectView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
            vibrancyView.translatesAutoresizingMaskIntoConstraints = false
            blurView.contentView.addSubview(vibrancyView)
        }
    }
    
    func highlightLetters(box: VNRectangleObservation) {
        let xCord = box.topLeft.x * capturedPhotoIV.frame.size.width
        let yCord = (1 - box.topLeft.y) * capturedPhotoIV.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * capturedPhotoIV.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * capturedPhotoIV.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.blue.cgColor
        
        if !magicSwitch.isOn {
            capturedPhotoIV.layer.addSublayer(outline)

        } else {
            outline.removeFromSuperlayer()
        }
    }
}
