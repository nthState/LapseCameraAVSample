//
//  ViewController.swift
//  RectCapture
//
//  Created by Ben Scheirman on 6/27/17.
//  Copyright © 2017 NSScreencast. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage
import LapseCameraEffect

class CaptureViewController: UIViewController {
    
    // MARK: - Properties
    
    private var cameraEffect: DistortEffect!
    
    lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()
    
    //var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayer: SampleBufferDisplayLayerView?
    
    //let sampleBufferQueue = DispatchQueue.global(qos: .userInteractive)
    let sampleBufferQueue = DispatchQueue.main
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraEffect = try! DistortEffect()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            setupCaptureSession()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (authorized) in
                DispatchQueue.main.async {
                    if authorized {
                        self.setupCaptureSession()
                    }
                }
            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.bounds = view.frame
    }
    
    // MARK: - Rotation
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
    
    // MARK: - Camera Capture
    
    private func findCamera() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInDualCamera,
            .builtInTelephotoCamera,
            .builtInWideAngleCamera
        ]
        
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                         mediaType: .video,
                                                         position: .back)
        
        return discovery.devices.first
    }
    
    private func setupCaptureSession() {
        guard captureSession.inputs.isEmpty else { return }
        guard let camera = findCamera() else {
            print("No camera found")
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            captureSession.addInput(cameraInput)
            
//            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
//            preview.frame = view.bounds
//            preview.backgroundColor = UIColor.black.cgColor
//            preview.videoGravity = .resizeAspect
//            view.layer.addSublayer(preview)
//            self.previewLayer = preview
            
            let preview = SampleBufferDisplayLayerView()
            preview.frame = view.bounds
            preview.backgroundColor = UIColor.black
            //preview.videoGravity = .resizeAspect
            view.layer.addSublayer(preview.layer)
            self.previewLayer = preview
            
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
            
            captureSession.addOutput(output)
            
            captureSession.startRunning()
            
        } catch let e {
            print("Error creating capture session: \(e)")
            return
        }
    }
    
}

extension CaptureViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var temp = sampleBuffer
        guard var videoPixelBuffer = CMSampleBufferGetImageBuffer(temp),
                 let formatDescription = CMSampleBufferGetFormatDescription(temp) else {
             return
           }
           
           if !cameraEffect.isPrepared {
             /*
              outputRetainedBufferCountHint is the number of pixel buffers the renderer retains. This value informs the renderer
              how to size its buffer pool and how many pixel buffers to preallocate. Allow 3 frames of latency to cover the dispatch_async call.
              */
             cameraEffect.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
           }
        
        CVPixelBufferLockBaseAddress(videoPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let config = CameraEffectAnimator.shared.getEffectConfiguration()
        //let config = EffectConfiguration(aberration: Aberration(red: 0, green: 0, blue: 0), blur: 20, distortion: 0)
        cameraEffect.applyInPlace(pixelBuffer: &videoPixelBuffer, with: config)

        CVPixelBufferUnlockBaseAddress(videoPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        if let videoLayer = self.previewLayer?.layer as? AVSampleBufferDisplayLayer {
            if videoLayer.isReadyForMoreMediaData {
                videoLayer.enqueue(temp)
            }
        }
        
    }
}
