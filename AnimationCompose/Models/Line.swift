//
//  Line.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 04.11.2024.
//

import UIKit

final class Line: NSObject {

    struct Settings {
        var width: CGFloat
        let alpha: CGFloat
        let blur: CGFloat?
        let blendMode: CGBlendMode
        let lineCap: CGLineCap
        let color: UIColor
        let isSmooth: Bool
    }

    let stroke: Stroke
    let settings: Settings

    init(stroke: Stroke, settings: Settings) {
        self.stroke = stroke
        self.settings = settings
    }

    init(line: Line) {
        stroke = Stroke(stroke: line.stroke)
        settings = line.settings
    }
}

final class Stroke {
    var points: [CGPoint]

    init(points: [CGPoint] = []) {
        self.points = points
    }

    init(stroke: Stroke) {
        points = stroke.points
    }
}
