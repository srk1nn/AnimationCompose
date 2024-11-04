//
//  HitchesRegulator.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 03.11.2024.
//

import Foundation

final class HitchesRegulator {
    private var hitchCount: Int = 0
    var onHitch: (() -> Void)?

    func registerHitch() {
        hitchCount += 1

        if hitchCount >= Constants.hitchLimit {
            onHitch?()
            hitchCount = 0
        }
    }

    func reset() {
        hitchCount = 0
    }

    private enum Constants {
        static let hitchLimit = 30
    }
}
