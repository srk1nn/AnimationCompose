//
//  BrushWidth.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 04.11.2024.
//

import Foundation

final class BrushWidth {
    let min: CGFloat
    let max: CGFloat
    var current: CGFloat

    init(min: CGFloat, max: CGFloat, current: CGFloat) {
        self.min = min
        self.max = max
        self.current = current
    }

    func percent() -> CGFloat {
        let normalize = current - min
        let distance = max - min
        return normalize / distance
    }

    func update(percent: CGFloat) {
        let distance = max - min
        let prenormalize = distance * percent
        current = min + prenormalize
    }
}
