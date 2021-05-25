//
//  Comparable+Extensions.swift
//  RectCapture
//
//  Created by Chris Davis on 25/05/2021.
//  Copyright © 2021 NSScreencast. All rights reserved.
//

import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
