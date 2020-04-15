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
    public static let `default` = CarouselConfiguration(geometry: .default, shadow: .default, autoCompletion: .default)

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
    
    public struct AutoCompletion {
        public static let `default` = AutoCompletion(
            swipeVelocityThreshold: 600.0, // points per second
            referenceRoundWidth: 300.0,
            minVelocity: 5.0, // rounds per second
            centeringVelocity: 5.0 // rounds per second
        )

        public var swipeVelocityThreshold: CGFloat
        public var referenceRoundWidth: CGFloat
        public var minVelocity: CGFloat
        public var centeringVelocity: CGFloat
    }
    
    public var geometry: Geometry
    public var shadow: Shadow
    public var autoCompletion: AutoCompletion
}
