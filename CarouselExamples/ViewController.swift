//
//  ViewController.swift
//  CarouselExamples
//
//  Created by Serhiy Medvedyev on 29.03.2020.
//  Copyright © 2020 Serhiy Medvedyev. All rights reserved.
//

import UIKit
import Carousel

private extension UIColor {
    static var random: UIColor {
        return UIColor(red: .random(in: 0...1),
                       green: .random(in: 0...1),
                       blue: .random(in: 0...1),
                       alpha: 1.0)
    }
}

class ViewController: UIViewController {
    @IBOutlet private var carouselView: CarouselView! {
        didSet {
            carouselView.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let numberOfSubviews = 5
        
        generateViews(numberOfSubviews).forEach { view in
            carouselView.addSubview(view)
        }
    }
}

extension UIViewController: CarouselViewDelegate {
    public func carouselDidSwipeToItem(at index: Int) {
        print("Did swipe to item at index \(index)")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    public func carouselItemTapped(at index: Int) {
        print("Item tapped at index \(index)")
    }
}

private extension ViewController {
    func generateViews(_ count: Int) -> [UIView] {
        return ( 0 ..< count ).map { _ in
            let view = UIView()
            view.backgroundColor = UIColor.random
            return view
        }
    }
}
