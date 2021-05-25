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
import CoreMedia

class CaptureViewController: UIViewController {
  
  // MARK: - Properties
  
  private var cameraEffect: DistortEffect!
  
  private var lastPixelBuffer: CVPixelBuffer?
  
  private var takePhoto: Bool = false
  
  lazy var captureSession: AVCaptureSession = {
    let session = AVCaptureSession()
    session.sessionPreset = .high
    return session
  }()
  
  var previewLayer: SampleBufferDisplayLayerView?
  
  //let sampleBufferQueue = DispatchQueue.global(qos: .userInteractive)
  let sampleBufferQueue = DispatchQueue.main
  
  // MARK: - View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    cameraEffect = try! DistortEffect()
  }
  
  func addTestButtons() {
    let takeButton = UIButton(frame: CGRect(x: 0, y: 200, width: 50, height: 50))
    takeButton.setTitle("Take", for: .normal)
    takeButton.addTarget(self, action: #selector(take(sender:)), for: .primaryActionTriggered)
    self.view.addSubview(takeButton)
    
    let resetButton = UIButton(frame: CGRect(x: 100, y: 200, width: 50, height: 50))
    resetButton.setTitle("Reset", for: .normal)
    resetButton.addTarget(self, action: #selector(reset(sender:)), for: .primaryActionTriggered)
    self.view.addSubview(resetButton)
  }
  
  @objc func take(sender: UIButton!) {
    CameraEffectAnimator.shared.resetTime()
    takePhoto = true
  }
  
  @objc func reset(sender: UIButton!) {
    lastPixelBuffer = nil
    takePhoto = false
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
      
      let preview = SampleBufferDisplayLayerView()
      preview.frame = view.bounds
      preview.backgroundColor = UIColor.green
      view.layer.addSublayer(preview.layer)
      self.previewLayer = preview
      
//      if let videoLayer = self.previewLayer?.layer as? AVSampleBufferDisplayLayer {
//        videoLayer.videoGravity = .resizeAspectFill
//        videoLayer.frame = self.view.bounds
//      }
//
//      if let conn = captureSession.connections.first {
//        conn.videoOrientation = .portrait
//        }
      
      let output = AVCaptureVideoDataOutput()
      output.alwaysDiscardsLateVideoFrames = true
      output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
      
      output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
      
      captureSession.addOutput(output)
      
      if let conn = output.connection(with: .video) {
        conn.videoOrientation = .portrait
      }

      captureSession.startRunning()
      
      addTestButtons()
    } catch let e {
      print("Error creating capture session: \(e)")
      return
    }
  }
  
}

extension CaptureViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    //connection.videoOrientation = AVCaptureVideoOrientation.portrait
    
    guard !takePhoto else {
      applyDistortion()
      return
    }
    
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      return
    }
    
    //let w = CVPixelBufferGetWidth(videoPixelBuffer)
    //let h = CVPixelBufferGetHeight(videoPixelBuffer)
    
    lastPixelBuffer = videoPixelBuffer
    
    if !cameraEffect.isPrepared {
      /*
       outputRetainedBufferCountHint is the number of pixel buffers the renderer retains. This value informs the renderer
       how to size its buffer pool and how many pixel buffers to preallocate. Allow 3 frames of latency to cover the dispatch_async call.
       */
      cameraEffect.prepare(with: formatDescription, outputRetainedBufferCountHint: 1)
    }
    
    display(sample: sampleBuffer)
  }
  
  func applyDistortion() {
    
    guard let last = lastPixelBuffer else {
      return
    }
    
    let config = CameraEffectAnimator.shared.getEffectConfiguration()
    let newPixelBuffer = cameraEffect.apply(pixelBuffer: last, with: config)
    
    // Debug the results
    //let orig = CIImage(cvPixelBuffer: last)
    //let new = CIImage(cvPixelBuffer: newPixelBuffer!)
    
    var newSampleBuffer: CMSampleBuffer? = nil
    var timingInfo: CMSampleTimingInfo = kCMTimingInfoInvalid
    var videoInfo: CMVideoFormatDescription? = nil

    CMVideoFormatDescriptionCreateForImageBuffer(nil, newPixelBuffer!, &videoInfo)
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, newPixelBuffer!, true, nil, nil, videoInfo!, &timingInfo, &newSampleBuffer)
    
    setSampleBufferAttachments(newSampleBuffer!)
    
    display(sample: newSampleBuffer!)
  }
  
  func setSampleBufferAttachments(_ sampleBuffer: CMSampleBuffer) {
      let attachments: CFArray! = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true)
      let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
          to: CFMutableDictionary.self)
      let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
      let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
      CFDictionarySetValue(dictionary, key, value)
  }
  
  func display(sample: CMSampleBuffer) {
    if let videoLayer = self.previewLayer?.layer as? AVSampleBufferDisplayLayer {
      if videoLayer.isReadyForMoreMediaData {
        videoLayer.enqueue(sample)
      }
    }
  }
  
}
