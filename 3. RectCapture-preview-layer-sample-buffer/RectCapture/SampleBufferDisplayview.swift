//
//  SampleBufferDisplayLayerView.swift
//  RectCapture
//
//  Created by Chris Davis on 17/05/2021.
//  Copyright © 2021 NSScreencast. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class SampleBufferDisplayLayerView: UIView {
  
  /*
   // Only override drawRect: if you perform custom drawing.
   // An empty implementation adversely affects performance during animation.
   override func drawRect(rect: CGRect)
   {
   // Drawing code
   }
   */
  
  override class var layerClass: AnyClass {
    return AVSampleBufferDisplayLayer.self
  }
}
