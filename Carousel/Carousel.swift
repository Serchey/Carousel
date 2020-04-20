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
        static let minimumStartingAngle: CGFloat = 0.001
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
    private var timerHasBeenCancelled: Bool = false
    private var previousTimerIncrement: CGFloat = 0.0

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

private extension CarouselView {
    func subviewsOrder(currentIndex: Int, numSlots: Int, totalSubviews: Int) -> [Int] {
        var visibleSubviewTags = [Int](0 ..< totalSubviews).rotated(from: 0, positions: currentIndex)

        while visibleSubviewTags.count > numSlots {
            visibleSubviewTags.remove(at: visibleSubviewTags.count / 2)
        }

        return visibleSubviewTags
    }
}

// MARK: - Rotation

private extension CarouselView {
    var isRotationEnabled: Bool {
        subviews.count > 1
    }

    func rotate(for points: CGFloat) {
        guard isRotationEnabled else {
            return
        }
        rotationAngle += points / rotationRadius
        setNeedsLayout()
    }

    func completePosition(with initialVelocity: CGFloat) {
        guard isRotationEnabled else {
            return
        }

        if rotationAngle == 0.0 {
            rotationAngle = initialVelocity > 0.0 ? Constant.minimumStartingAngle : -Constant.minimumStartingAngle
        }

        let velocity = initialVelocity / configuration.autoCompletion.referenceCircleDiameter * containerWidth
        let isRotationAngleCompensated = velocity * rotationAngle < 0 // if sign is different
        let currentAngle = isRotationAngleCompensated ? ( abs(rotationAngle) - angleStride ) : rotationAngle
        let previousTimerDirectionMatchesWithCurrentDirection = previousTimerIncrement * initialVelocity > 0
        var distanceToComplete = angleStride - abs(currentAngle)

        if timerHasBeenCancelled && isRotationAngleCompensated && previousTimerDirectionMatchesWithCurrentDirection {
            distanceToComplete += angleStride
        }
        
        let minimumAutoCompletionVelocity = configuration.autoCompletion.minVelocity * containerWidth
        
        let linearVelocity: CGFloat = velocity > 0 ?
            max(velocity, minimumAutoCompletionVelocity) : min(velocity, -minimumAutoCompletionVelocity)

        let angleIncrement = linearVelocity * CGFloat(Constant.rotationUpdateInterval) / rotationRadius

        startRotation(angleIncrement: angleIncrement, distanceToComplete: distanceToComplete, alreadyPassed: 0.0)
    }

    func centerPosition() {
        guard rotationTimer == nil, isRotationEnabled else {
            return
        }

        let autoCenteringVelocity = configuration.autoCompletion.centeringVelocity * containerWidth
        let angleIncrement = autoCenteringVelocity * CGFloat(Constant.rotationUpdateInterval) / rotationRadius
        let signedAngleIncrement = rotationAngle < 0 ? angleIncrement : -angleIncrement

        startRotation(angleIncrement: signedAngleIncrement, distanceToComplete: angleStride, alreadyPassed: angleStride - abs(rotationAngle))
    }
    
    func startRotation(angleIncrement: CGFloat, distanceToComplete: CGFloat, alreadyPassed: CGFloat) {
        var distancePassed = alreadyPassed
        let onePixel = 1.0 / UIScreen.main.scale
        let isIncrementNegative = angleIncrement < 0
        let incrementAbs = abs(angleIncrement)

        previousTimerIncrement = angleIncrement
        
        let timer = Timer(timeInterval: Constant.rotationUpdateInterval, repeats: true) { [weak self, rotationRadius = rotationRadius] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let passed = distancePassed / distanceToComplete
            let distanceRemained = distanceToComplete - distancePassed
            let onePixelIncrement = onePixel / rotationRadius
            let increment = max(onePixelIncrement, min(distanceRemained, incrementAbs * cos(Constant.quarterCircle * passed)))
            
            distancePassed += increment
            
            self.rotationAngle += isIncrementNegative ? -increment : increment

            if abs(self.rotationAngle) * rotationRadius < onePixel {
                timer.invalidate()
                self.rotationTimer = nil
                self.rotationAngle = 0.0
                self.timerHasBeenCancelled = false
            }
            
            self.setNeedsLayout()
        }
        
        rotationTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func cancelAutoRotation() {
        guard let rotationTimer = rotationTimer else {
            return
        }

        rotationTimer.invalidate()
        self.rotationTimer = nil
        timerHasBeenCancelled = true
    }
}

// MARK: - Gesture handling

private extension CarouselView {
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)
        let velocity = gestureRecognizer.velocity(in: self)

        gestureRecognizer.setTranslation(.zero, in: self)

        switch gestureRecognizer.state {
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
        case .began, .failed, .possible:
            break
        @unknown default:
            break
        }
    }
    
    @objc func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard case .ended = gestureRecognizer.state else {
            return
        }

        guard let subview = subviews.first(where: { $0.tag == currentIndex }) else {
            return
        }

        guard subview.bounds.contains(gestureRecognizer.location(in: subview)) else {
            return
        }
        
        delegate?.carouselItemTapped(at: subview.tag)
    }

    @objc func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            cancelAutoRotation()
        case .ended, .cancelled, .failed:
            if timerHasBeenCancelled {
                centerPosition()
            }
        default:
            break
        }
    }

    func setupGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(_:)))
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPressGesture(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.0
        longPressGestureRecognizer.delegate = self
        addGestureRecognizer(longPressGestureRecognizer)
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
        guard gestureRecognizers?.contains(gestureRecognizer) == true else {
            return false
        }
        
        if gestureRecognizer is UILongPressGestureRecognizer {
            return true
        }
        
        return gestureRecognizer is UITapGestureRecognizer && !(otherGestureRecognizer is UIPanGestureRecognizer)
    }
}
