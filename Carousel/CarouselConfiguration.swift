//
//  CarouselConfiguration.swift
//  Carousel
//
//  Created by Serhiy Medvedyev on 02.04.2020.
//  Copyright © 2020 Serhiy Medvedyev. All rights reserved.
//

import Foundation
import UIKit

public struct CarouselConfiguration {
    public static let `default` = CarouselConfiguration(geometry: .default, shadow: .default, gestures: .default)

    public struct Geometry {
        public static let `default` = Geometry(
            aspectRatio: nil,
            topBottomOffset: 10,
            parallax: 0.08,
            minSlotsPerCircle: 2,
            maxSlotsPerCircle: 4
        )

        public var aspectRatio: CGFloat?
        public var topBottomOffset: CGFloat
        public var parallax: CGFloat
        public var minSlotsPerCircle: Int
        public var maxSlotsPerCircle: Int
    }
    
    public struct Shadow {
        public static let `default` = Shadow(
            radius: 3.0,
            color: UIColor.black.cgColor,
            opacity: 0.25,
            offset: .init(width: 0.0, height: 0.0)
        )

        public var radius: CGFloat
        public var color: CGColor
        public var opacity: Float
        public var offset: CGSize
    }
    
    public struct Gestures {
        public static let `default` = Gestures(
            rotationTimerInterval: 1.0 / 60.0, // 60 fps
            autoCompletionThreshold: 600.0,  // pt/sec
            autoCompletionMinVelocity: 1200.0, // pt/sec
            autoCenteringVelocity: 1600.0 // pt/sec
        )

        public var rotationTimerInterval: TimeInterval
        public var autoCompletionThreshold: CGFloat
        public var autoCompletionMinVelocity: CGFloat
        public var autoCenteringVelocity: CGFloat
    }
    
    public var geometry: Geometry
    public var shadow: Shadow
    public var gestures: Gestures
}
