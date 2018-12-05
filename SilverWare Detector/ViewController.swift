//
//  ViewController.swift
//  SilverWare Detector
//
//  Created by James Jarrett on 12/1/18.
//  Copyright © 2018 James Jarrett. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }
    
    let session = AVCaptureSession()
    
    let captureQueue = DispatchQueue(label: "captureQueue")
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var resultView: UILabel!
    
    var visionsRequests = [VNRequest]()
    
    var recognitionThreshold : Float = 0.25
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        resultView.sizeToFit()
        // Do any additional setup after loading the view, typically from a nib.
        guard let camera = AVCaptureDevice.default(for: .video) else {
            fatalError("No video camera available")
        }
        
  
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewView.layer.addSublayer(previewLayer)
            
            let cameraInput =  try! AVCaptureDeviceInput(device: camera)
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            session.addInput(cameraInput)
            session.addOutput(videoOutput)
            
            let conn = videoOutput.connection(with: .video)
            conn?.videoOrientation = .portrait
            
            //Start the session
            session.startRunning()
            session.sessionPreset = .high
            
            
            guard let visionModel = try? VNCoreMLModel(for: silverware().model) else {
                fatalError("Could not load model")
            }
            let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] classificationRequest, error in self?.handleClassifications(request: classificationRequest, error: error)

            })

            classificationRequest.imageCropAndScaleOption = .centerCrop
            visionsRequests = [classificationRequest]

        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = self.previewView.bounds
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption: Any] = [:]
        
        if let cameraIntriniscData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntriniscData]
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 1)!, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.visionsRequests)
        } catch {
            print(error)
        }
    }
    
    func handleClassifications(request: VNRequest, error: Error?) {
        if let theError = error {
            print("Error: \(theError.localizedDescription)")
            return
        }
        guard let observations = request.results else {
            print("No result")
            return
        }
        let classifications = observations[0...2]
            
            .compactMap({ $0 as? VNClassificationObservation})
            .map({"\($0.identifier) \(($0.confidence * 100).rounded())"})
            .joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.resultView.text = classifications
        }
    }



}

