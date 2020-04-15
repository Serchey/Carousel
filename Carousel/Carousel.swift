//
//  Carousel.swift
//  Carousel
//
//  Created by Serhiy Medvedyev on 01.04.2020.
//  Copyright © 2020 Serhiy Medvedyev. All rights reserved.
//

import Foundation
import UIKit

public protocol CarouselViewDelegate: class {
    func carouselDidSwipeToItem(at index: Int)
    func carouselItemTapped(at index: Int)
}

public final class CarouselView: UIView {
    enum Constant {
        static let rotationUpdateInterval: TimeInterval = 1.0 / 60.0 // 60 fps
        static let fullCircle: CGFloat = .pi * 2.0
        static let quarterCircle: CGFloat = .pi / 2.0
    }
    
    public var configuration: CarouselConfiguration = .default
    public weak var delegate: CarouselViewDelegate?

    private var currentSlotSize: CGSize?
    private var rotationAngle: CGFloat = 0.0
    private var rotationTimer: Timer?
    private(set) var currentIndex: Int = 0 {
        didSet {
            if currentIndex != oldValue {
                delegate?.carouselDidSwipeToItem(at: currentIndex)
            }
        }
    }

    // MARK: - Initialization
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupGestureRecognizers()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestureRecognizers()
    }
    
    // MARK: - Overrides

    override public func didAddSubview(_ subview: UIView) {
        subview.tag = subviews.count - 1
        
        setupShadow(for: subview)
        
        super.didAddSubview(subview)
    }

    override public func layoutSubviews() {
        let stride = angleStride
        let previousCurrentIndex = currentIndex

        updateSlotsSizeIfNeeded()

        let subviewTags = subviewsOrder(currentIndex: currentIndex, numSlots: slotsPerCircle, totalSubviews: subviews.count)

        for subview in subviews {
            guard let index = subviewTags.firstIndex(where: { subview.tag == $0 }) else {
                subview.isHidden = true
                continue
            }
            
            let angle = CGFloat(index) * stride + rotationAngle

            subview.center = slotCenter(for: angle)
            subview.transform = slotTransform(for: angle)
            subview.isHidden = isSlotHidden(for: angle)

            if shouldBringSubviewToFront(for: angle) {
                bringSubviewToFront(subview)
                currentIndex = subview.tag
            }
        }

        if currentIndex != previousCurrentIndex {
            compensateRotationAngle(with: stride)
        }
    }
}

// MARK: - Geometry

private extension CarouselView {
    var containerWidth: CGFloat {
        return bounds.width
    }

    var slotSize: CGSize {
        guard configuration.geometry.aspectRatio != nil || bounds.height != 0.0 else {
            return .zero
        }

        let maxWidth = containerWidth
        let maxHeight = bounds.height
        let aspectRatio = configuration.geometry.aspectRatio ?? maxWidth / maxHeight
        let availableHeight = maxHeight - configuration.geometry.topBottomOffset * 2
        
        guard availableHeight * aspectRatio <= maxWidth else {
            return .init(width: maxWidth, height: maxWidth / aspectRatio)
        }

        return .init(width: availableHeight * aspectRatio, height: availableHeight)
    }
    
    func setupShadow(for view: UIView) {
        view.layer.shadowColor = configuration.shadow.color
        view.layer.shadowRadius = configuration.shadow.radius
        view.layer.shadowOpacity = configuration.shadow.opacity
        view.layer.shadowOffset = configuration.shadow.offset
    }
    
    func updateSlotsSizeIfNeeded() {
        let newSlotSize = slotSize

        guard currentSlotSize != newSlotSize else {
            return

        }
        subviews.forEach { subview in
            subview.bounds.size = newSlotSize
        }

        currentSlotSize = newSlotSize
    }
}

// MARK: - Trigonometry

extension CarouselView {
    private var slotsPerCircle: Int {
        return min(configuration.geometry.maxSlotsPerCircle, max(subviews.count, configuration.geometry.minSlotsPerCircle))
    }
    
    private var angleStride: CGFloat {
        return Constant.fullCircle / CGFloat(slotsPerCircle)
    }
    
    private var rotationRadius: CGFloat {
        return slotSize.width / sin(angleStride / 2.0) / 2.0
    }
    
    private func slotCenter(for angle: CGFloat) -> CGPoint {
        let x = sin(angle) * rotationRadius
        return .init(x: bounds.width / 2.0 + x, y: bounds.height / 2.0)
    }
    
    private func slotTransform(for angle: CGFloat) -> CGAffineTransform {
        let scale = ( 1.0 - configuration.geometry.parallax ) + configuration.geometry.parallax * cos(angle)
        return .init(scaleX: scale, y: scale)
    }
    
    private func isSlotHidden(for angle: CGFloat) -> Bool {
        let thresholdAngle = angleStride < Constant.quarterCircle ? 0.0 : -sin(angleStride / 2.0)
        return cos(angle) < thresholdAngle
    }
    
    private func shouldBringSubviewToFront(for angle: CGFloat) -> Bool {
        return cos(angle) > cos(angleStride / 2.0)
    }
    
    private func compensateRotationAngle(with stride: CGFloat) {
        if rotationAngle > 0.0 {
            rotationAngle -= stride
        }
        else {
            rotationAngle += stride
        }
    }
}

// MARK: - Subview ordering

extension CarouselView {
    private func subviewsOrder(currentIndex: Int, numSlots: Int, totalSubviews: Int) -> [Int] {
        var visibleSubviewTags = [Int](0 ..< totalSubviews).rotated(from: 0, positions: currentIndex)

        while visibleSubviewTags.count > numSlots {
            visibleSubviewTags.remove(at: visibleSubviewTags.count / 2)
        }

        return visibleSubviewTags
    }
}

// MARK: - Gesture managing

extension CarouselView {
    private func rotate(for points: CGFloat) {
        rotationAngle += points / rotationRadius
        setNeedsLayout()
    }

    private func completePosition(with initialVelocity: CGFloat) {
        guard rotationAngle != 0 else {
            return
        }

        let velocity = initialVelocity / configuration.autoCompletion.referenceRoundWidth * containerWidth
        let isRotationAngleCompensated = velocity * rotationAngle < 0 // if sign is different
        let currentAngle = isRotationAngleCompensated ? ( abs(rotationAngle) - angleStride ) : rotationAngle
        let distanceToComplete = angleStride - abs(currentAngle)
        let minimumAutoCompletionVelocity = configuration.autoCompletion.minVelocity * containerWidth
        
        let linearVelocity: CGFloat = velocity > 0 ?
            max(velocity, minimumAutoCompletionVelocity) : min(velocity, -minimumAutoCompletionVelocity)

        let angleIncrement = linearVelocity * CGFloat(Constant.rotationUpdateInterval) / rotationRadius
        
        startRotation(angleIncrement: angleIncrement, distanceToComplete: distanceToComplete, alreadyPassed: 0.0)
    }

    private func centerPosition() {
        let autoCenteringVelocity = configuration.autoCompletion.centeringVelocity * containerWidth
        let angleIncrement = autoCenteringVelocity * CGFloat(Constant.rotationUpdateInterval) / rotationRadius
        let signedAngleIncrement = rotationAngle < 0 ? angleIncrement : -angleIncrement

        startRotation(angleIncrement: signedAngleIncrement, distanceToComplete: angleStride, alreadyPassed: angleStride - abs(rotationAngle))
    }
    
    private func startRotation(angleIncrement: CGFloat, distanceToComplete: CGFloat, alreadyPassed: CGFloat) {
        var distancePassed = alreadyPassed
        let onePixel = 1.0 / UIScreen.main.scale
        let isIncrementNegative = angleIncrement < 0
        let incrementAbs = abs(angleIncrement)

        let timer = Timer(timeInterval: Constant.rotationUpdateInterval, repeats: true) { [weak self, rotationRadius = rotationRadius] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let passed = distancePassed / distanceToComplete
            let distanceRemained = distanceToComplete - distancePassed
            let increment = min(distanceRemained, incrementAbs * cos(Constant.quarterCircle * passed))

            distancePassed += abs(increment)
            
            self.rotationAngle += isIncrementNegative ? -increment : increment
            
            if abs(self.rotationAngle) * rotationRadius < onePixel {
                self.rotationAngle = 0.0
                timer.invalidate()
            }
            
            self.setNeedsLayout()
        }
        
        rotationTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    @objc private func handlePanGesture(_ panGestureRecognizer: UIPanGestureRecognizer) {
        let translation = panGestureRecognizer.translation(in: self)
        let velocity = panGestureRecognizer.velocity(in: self)

        panGestureRecognizer.setTranslation(.zero, in: self)

        switch panGestureRecognizer.state {
        case .began:
            rotationTimer?.invalidate()
        case .changed:
            rotate(for: translation.x)
        case .ended, .cancelled:
            rotate(for: translation.x)
            if abs(velocity.x) > configuration.autoCompletion.swipeVelocityThreshold {
                completePosition(with: velocity.x)
            }
            else {
                centerPosition()
            }
        case .failed, .possible:
            break
        @unknown default:
            break
        }
    }
    
    @objc private func handleTapGesture(_ tapGestureRecognizer: UITapGestureRecognizer) {
        guard case .ended = tapGestureRecognizer.state else {
            return
        }

        guard let subview = subviews.first(where: { $0.tag == currentIndex }) else {
            return
        }

        guard subview.bounds.contains(tapGestureRecognizer.location(in: subview)) else {
            return
        }
        
        delegate?.carouselItemTapped(at: subview.tag)
    }

    private func setupGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(_:)))
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
    }
}

extension CarouselView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = panGestureRecognizer.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UITapGestureRecognizer && gestureRecognizers?.contains(gestureRecognizer) == true &&
            !(otherGestureRecognizer is UIPanGestureRecognizer)
    }
}
