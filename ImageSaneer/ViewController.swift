//
//  ViewController.swift
//  ImageSaneer
//
//  Created by Jacob Vinu on 25/04/19.
//  Copyright © 2019 Jacob Vinu. All rights reserved.
//

import UIKit
import AVFoundation

var capturesSession : AVCaptureSession?
var stillImageOutput : AVCapturePhotoOutput?
var backCamera : AVCaptureDevice?
var videoPreviewLayer: AVCaptureVideoPreviewLayer?
var settings : AVCapturePhotoSettings?

var flasStatus = Bool()

class ViewController: UIViewController,AVCapturePhotoCaptureDelegate {
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var btnFlash: UIButton!
    @IBOutlet weak var capturedImage: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        flasStatus = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        ////////// Setup the camera view ////////////////////
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.black]
        capturesSession = AVCaptureSession()
        capturesSession?.sessionPreset = .photo
        backCamera = AVCaptureDevice.default(for: .video)
        if !(backCamera != nil) {
            print("Unable to access back camera!")
            return
        }
        var error: Error?
        let input = try? AVCaptureDeviceInput(device: backCamera!)
        if error == nil {
        } else {
            print("Error Unable to initialize back camera: \(error?.localizedDescription ?? "")")
        }
        if #available(iOS 10.0, *) {
            stillImageOutput = AVCapturePhotoOutput()
        } else {
            // Fallback on earlier versions
        }
        
        if capturesSession!.canAddInput(input!) && capturesSession!.canAddOutput(stillImageOutput!){
            capturesSession?.addInput(input!)
            capturesSession?.addOutput(stillImageOutput!)
            setupLivePreview()
        }
        ///////////////////////////////////////////////////////
        
    }
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: capturesSession!)
        //if videoPreviewLayer
        videoPreviewLayer!.videoGravity = .resizeAspectFill
        videoPreviewLayer!.connection?.videoOrientation = .portrait
        self.view.layer.addSublayer(videoPreviewLayer!)
        let globalQueue = DispatchQueue.global(qos: .default)
        globalQueue.async(execute: {
            capturesSession!.startRunning()
            DispatchQueue.main.async(execute: {
                videoPreviewLayer!.frame = self.view.frame
                
                ///////// Add overlay to the camera view //////////////
                self.addoverlay()
                ///////////////////////////////////////////////////////
            })
        })
    }
    func addoverlay()  {
        // Create a view filling the screen.
        let overlay = UIView(frame: CGRect(x:0, y:0,width: UIScreen.main.bounds.width, height:UIScreen.main.bounds.height))
        // Set a semi-transparent, black background.
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        // Create the initial layer from the view bounds.
        let maskLayer = CAShapeLayer()
        maskLayer.frame = overlay.bounds
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.7).cgColor
        // Create the frame for the inner frame.
        let radius: CGFloat = 20.0
        let rect = UIBezierPath(roundedRect:  CGRect(x: self.view.frame.size.width / 2 - 125,y: self.view.frame.size.height/2 - 125 ,width:250,height:250), byRoundingCorners:.allCorners, cornerRadii: CGSize(width:radius, height:radius))
        // Create the path.
        let path = UIBezierPath(rect: overlay.bounds)
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        // Append the circle to the path so that it is subtracted.
        path.append(rect)
        maskLayer.path = path.cgPath
        // Set the mask of the view.
        overlay.layer.mask = maskLayer
        // Create the path.
        // Add the view so it is visible.
        self.view.addSubview(overlay)
        // place the camera control view above the overlay
        self.view.insertSubview(previewView, aboveSubview: overlay)
    }
    
    @IBAction func focusAction(_ sender: Any) {
        try? backCamera!.lockForConfiguration()
        backCamera!.focusMode = .autoFocus
        backCamera!.focusPointOfInterest = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height / 2)
    }
    
    @IBAction func cameraAction(_ sender: Any) {
        if #available(iOS 11.0, *) {
            settings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: AVVideoCodecType.jpeg.rawValue
                ])
            stillImageOutput!.capturePhoto(with: settings!, delegate: self)
        } else {
            // Fallback on earlier versions
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let imageData: Data? = photo.fileDataRepresentation()
        var image: UIImage? = nil
        if let imageData = imageData {
            // original image that captured
            image = UIImage(data: imageData)
            let viewsize : CGRect = self.view.frame
            // Ratio of rectangle overlay with respect to the view. We put '250' because of the rectangle overlay width is 250.
            let ratioOfRect : CGFloat = 250/viewsize.size.height
            // size of the portion to be cropped from the whole image that captured
            let croppedSize : CGFloat = (image?.size.height)! * ratioOfRect
            // cropping the rectangle portion from the original image
            var capturedImageFormCamera : UIImage = self.image(byCroppingImage: image, to: CGSize(width: croppedSize, height: croppedSize))!
            // rotate the image
            capturedImageFormCamera = self.rotateUIImage(capturedImageFormCamera, clockwise: true)!
            capturedImage.image = capturedImageFormCamera
        }
    }
    
    func image(byCroppingImage image: UIImage?, to size: CGSize) -> UIImage? {
        // not equivalent to image.size (which depends on the imageOrientation)!
        let refWidth = Double((image?.cgImage?.width)!)
        let refHeight = Double((image?.cgImage?.height)!)
        let x = (refWidth - Double(size.width)) / 2.0
        let y = (refHeight - Double(size.height)) / 2.0
        let cropRect = CGRect(x: CGFloat(x), y: CGFloat(y), width: size.height, height: size.width)
        let imageRef = image?.cgImage?.cropping(to: cropRect)
        var cropped: UIImage? = nil
        if let imageRef = imageRef {
            cropped = UIImage(cgImage: imageRef, scale: 0.0, orientation: .up)
        }
        return cropped
    }
    
    func rotateUIImage(_ sourceImage: UIImage?, clockwise: Bool) -> UIImage? {
        let size: CGSize? = sourceImage?.size
        UIGraphicsBeginImageContext(CGSize(width: size?.height ?? 0.0, height: size?.width ?? 0.0))
        if let cg = sourceImage?.cgImage {
            UIImage(cgImage: cg, scale: 1.0, orientation: clockwise ? .right : .left).draw(in: CGRect(x: 0, y: 0, width: size?.height ?? 0.0, height: size?.width ?? 0.0))
        }
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }

    @IBAction func flasAction(_ sender: Any) {
        if flasStatus {
            flasStatus = false
            try? backCamera?.lockForConfiguration()
            backCamera?.torchMode = .off
            settings?.flashMode = .off
            btnFlash.setImage(UIImage(named: "flash_off.png"), for: .normal)
        } else {
            flasStatus = true
            try? backCamera?.lockForConfiguration()
            backCamera?.torchMode = .on
            settings?.flashMode = .on
            btnFlash.setImage(UIImage(named: "flash_on.png"), for: .normal)
        }
        backCamera?.unlockForConfiguration()
    }
}

