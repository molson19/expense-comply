//
//  ViewController.swift
//  SwiftOCR Camera
//
//  Created by Nicolas Camenisch on 04.05.16.
//  Copyright © 2016 Nicolas Camenisch. All rights reserved.
//

import UIKit
import SwiftOCR
import AVFoundation
import Alamofire
import NVActivityIndicatorView

extension UIImage {
    func detectOrientationDegree () -> CGFloat {
        switch imageOrientation {
        case .right, .rightMirrored:    return 90
        case .left, .leftMirrored:      return -90
        case .up, .upMirrored:          return 180
        case .down, .downMirrored:      return 0
        }
    }
}

func convertImageToBase64(image: UIImage) -> String {
    let imageData = UIImagePNGRepresentation(image)!
    return imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
}

class ViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var viewFinder: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var label: UILabel!
    
    
    @IBOutlet weak var spinner: NVActivityIndicatorView!
    //Top level Modal
    
    @IBOutlet weak var topLevelModal: UIView!
    @IBOutlet weak var itemName: UITextField!
    @IBOutlet weak var price: UITextField!
    @IBOutlet weak var compliesBool: UITextField!
    
    @IBOutlet weak var dailyLimit: UITextField!
    
    
    // MARK: - Private Properties
    fileprivate var stillImageOutput: AVCaptureStillImageOutput!
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let device  = AVCaptureDevice.default(for: AVMediaType.video)
    private let ocrInstance = SwiftOCR()
    
    // MARK: - View LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // start camera init
        DispatchQueue.global(qos: .userInitiated).async {
            if self.device != nil {
                self.configureCameraForUse()
            }
        }
        
        //
        //tabBarController?.tabBar.barTintColor =
        
        //UIColor(red:0.09, green:0.11, blue:0.13, alpha:1.0)
            UINavigationBar.appearance().barTintColor = UIColor(red:0.09, green:0.11, blue:0.13, alpha:1.0)
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        UINavigationBar.appearance().isTranslucent = false
        
        //MARK:- Hide Status Bar
        
        
        UIApplication.shared.isStatusBarHidden = true
        slider.isHidden = true
        
        let gesture = UITapGestureRecognizer(target: self, action:  #selector(self.takePhoto))
        self.cameraView.addGestureRecognizer(gesture)
        
        //Top level modal styling
        topLevelModal.layer.cornerRadius = 7
        
    
        
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        self.setNeedsStatusBarAppearanceUpdate()
//    }
//    override var preferredStatusBarStyle : UIStatusBarStyle {
//        return .lightContent
//    }

    @objc func takePhoto(sender : UITapGestureRecognizer) {
        self.spinner.startAnimating()
        DispatchQueue.global(qos: .userInitiated).async {
            
            guard let capturedType = self.stillImageOutput.connection(with: AVMediaType.video) else {
                return
            }
            
            self.stillImageOutput.captureStillImageAsynchronously(from: capturedType) { [weak self] optionalBuffer, error -> Void in
                guard let buffer = optionalBuffer else {
                    return
                }
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                let image = UIImage(data: imageData!)
                
                
                if (self!.topLevelModal.frame.origin.y == 520) {
                    UIView.animate(withDuration: 0.5, animations: {
                        self?.topLevelModal.frame.origin.y = 700

                    }, completion: nil)
                }
                
                
                let croppedImage = self?.prepareImageForCrop(using: image!)
                
                let imageToSend = convertImageToBase64(image: croppedImage!)
                print("base64:")
                //                print(imageToSend)
                
                
                let params:Parameters = [
                    "country": "Germany",
                    "tipType": "Restaurant",
                    "image": imageToSend
                ]
                
                let apiUrl = "https://warm-sea-40636.herokuapp.com/api/image"
                
                Alamofire.request(apiUrl, method: .post, parameters: params, encoding: JSONEncoding.default)
                    .responseJSON { response in
                        //                        print(response)
                        
                        //                        print(response["item"] as! String)
                        if let JSON = response.result.value as? [String: Any] {
                            /*
                             "defaultTipAmount": "0",
                             "tipDescription": "Typically service charge is included; plus, tip 5% -10%",
                             "convertedAmount": 13.6580928,
                             "item": "Large Coffee",
                             "currency": "EUR"
                             */
                            
        
                            
                            self!.itemName.text = JSON["item"] as! String
                            self!.price.text = "\(JSON["convertedAmount"] as! String) USD"
                            
                            if (JSON["complies"] as! String == "true") {
                                self!.compliesBool.text = "✅"
                                let price = Double(JSON["convertedAmount"] as! String)! / 100.00
                                self!.dailyLimit.text = "\(round(price * 100))% of your daily limit"
                                
                                let string = "\(JSON["item"] as! String) complies with policy"
                                let utterance = AVSpeechUtterance(string: string)
                                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                                
                                let synth = AVSpeechSynthesizer()
                                synth.speak(utterance)
                                
                            } else {
                                self!.compliesBool.text = "⛔️"
                                
                                self!.dailyLimit.text = "\(JSON["item"] as! String) does not comply with travel policy"
                                
                                let string = "\(JSON["item"] as! String) does not comply with policy"
                                let utterance = AVSpeechUtterance(string: string)
                                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                                
                                let synth = AVSpeechSynthesizer()
                                synth.speak(utterance)
                                
                            }
                            
                            
                            
                            
                        }
                        
                        
                        UIView.animate(withDuration: 0.5, animations: {
                            self?.topLevelModal.frame.origin.x = 20
                            self?.topLevelModal.frame.origin.y = 520
                        }, completion: nil)
                        self!.spinner.stopAnimating()
                        
                        //                        var requests: [String:Any] = response["request"]
                        //                        print(requests)
                        //
                        //                        if let requests = response["request"] as? NSDictionary {
                        //                            print(requests)
                        ////                            if let timeEntry = entry["time"] as? String {
                        ////                                if let activityEntry = entry["activity"] as? String  {
                        ////                                    time.append(timeEntry)
                        ////                                    activity.append(activityEntry)
                        ////                                }
                        ////                            }
                        //                        }
                }
                //                self?.ocrInstance.recognize(croppedImage!) { [weak self] recognizedString in
                //                    DispatchQueue.main.async {
                //                        self?.label.text = recognizedString
                //                        print(self?.ocrInstance.currentOCRRecognizedBlobs ?? "Recoginzed Blob is empty")
                //                    }
                //                }
                
            }
        }
    }
    
//    // MARK: - IBActions
//    @IBAction func takePhotoButtonPressed (_ sender: UIButton) {
//        
//    }
    
    @IBAction func sliderValueDidChange(_ sender: UISlider) {
        do {
            try device!.lockForConfiguration()
            var zoomScale = CGFloat(slider.value * 10.0)
            let zoomFactor = device?.activeFormat.videoMaxZoomFactor
            
            if zoomScale < 1 {
                zoomScale = 1
            } else if zoomScale > zoomFactor! {
                zoomScale = zoomFactor!
            }
            
            device?.videoZoomFactor = zoomScale
            device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
    }
}

extension ViewController {
    // MARK: AVFoundation
    fileprivate func configureCameraForUse () {
        self.stillImageOutput = AVCaptureStillImageOutput()
        let fullResolution = UIDevice.current.userInterfaceIdiom == .phone && max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height) < 568.0
        
        if fullResolution {
            self.captureSession.sessionPreset = AVCaptureSession.Preset.photo
        } else {
            self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        }
        
        self.captureSession.addOutput(self.stillImageOutput)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepareCaptureSession()
        }
    }
    
    private func prepareCaptureSession () {
        do {
            self.captureSession.addInput(try AVCaptureDeviceInput(device: self.device!))
        } catch {
            print("AVCaptureDeviceInput Error")
        }
        
        // layer customization
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayer.frame.size = self.cameraView.frame.size
        previewLayer.frame.origin = CGPoint.zero
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // device lock is important to grab data correctly from image
        do {
            try self.device?.lockForConfiguration()
            self.device?.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.device?.focusMode = .continuousAutoFocus
            self.device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        //Set initial Zoom scale
        do {
            try self.device?.lockForConfiguration()
            
            let zoomScale: CGFloat = 2.5
            
            if zoomScale <= (device?.activeFormat.videoMaxZoomFactor)! {
                device?.videoZoomFactor = zoomScale
            }
            
            device?.unlockForConfiguration()
        } catch {
            print("captureDevice?.lockForConfiguration() denied")
        }
        
        DispatchQueue.main.async(execute: {
            self.cameraView.layer.addSublayer(previewLayer)
            self.captureSession.startRunning()
        })
    }
    
    // MARK: Image Processing
    fileprivate func prepareImageForCrop (using image: UIImage) -> UIImage {
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat(Double.pi)
        }
        
        let imageOrientation = image.imageOrientation
        let degree = image.detectOrientationDegree()
        let cropSize = CGSize(width: 400, height: 110)
        
        //Downscale
        let cgImage = image.cgImage!
        
        let width = cropSize.width
        let height = image.size.height / image.size.width * cropSize.width
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        let context = CGContext(data: nil,
                                width: Int(width),
                                height: Int(height),
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace!,
                                bitmapInfo: bitmapInfo.rawValue)
        
        context!.interpolationQuality = CGInterpolationQuality.none
        // Rotate the image context
        context?.rotate(by: degreesToRadians(degree));
        // Now, draw the rotated/scaled image into the context
        context?.scaleBy(x: -1.0, y: -1.0)
        
        //Crop
        switch imageOrientation {
        case .right, .rightMirrored:
            context?.draw(cgImage, in: CGRect(x: -height, y: 0, width: height, height: width))
        case .left, .leftMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: -width, width: height, height: width))
        case .up, .upMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        case .down, .downMirrored:
            context?.draw(cgImage, in: CGRect(x: -width, y: -height, width: width, height: height))
        }
        
        let calculatedFrame = CGRect(x: 0, y: CGFloat((height - cropSize.height)/2.0), width: cropSize.width, height: cropSize.height)
        let scaledCGImage = context?.makeImage()?.cropping(to: calculatedFrame)
        
        
        return UIImage(cgImage: scaledCGImage!)
    }
    
}
