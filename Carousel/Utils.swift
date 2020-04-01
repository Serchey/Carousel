//
//  Utils.swift
//  Carousel
//
//  Created by Serhiy Medvedyev on 01.04.2020.
//  Copyright © 2020 Serhiy Medvedyev. All rights reserved.
//

import Foundation

extension Array {
    mutating func rotate(from index: Int, positions: Int) {
        guard index < count else {
            return
        }
        
        let shift = index + positions % (count - index)
        
        self[index..<shift].reverse()
        self[shift..<self.count].reverse()
        self[index..<self.count].reverse()
    }
    
    func rotated(from index: Int, positions: Int) -> [Element] {
        var mutableCopy = self
        mutableCopy.rotate(from: index, positions: positions)
        return mutableCopy
    }
}
