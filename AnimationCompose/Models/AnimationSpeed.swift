//
//  AnimationSpeed.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 04.11.2024.
//

import Foundation

enum AnimationSpeedOption: CaseIterable {
    case total
    case frame

    var name: String {
        switch self {
        case .total:
            "Общая"
        case .frame:
            "Кадра"
        }
    }
}

struct AnimationSpeed {
    let option: AnimationSpeedOption
    let duration: TimeInterval

    func secondsPerFrame(framesCount: Int) -> TimeInterval {
        switch option {
        case .total:
            return duration / Double(framesCount)
        case .frame:
            return duration
        }
    }
}
