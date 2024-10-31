//
//  GIFGenerator.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 29.10.2024.
//

import UIKit
import UniformTypeIdentifiers

enum GIFGeneratorError: LocalizedError {
    case creation

    var errorDescription: String? {
        switch self {
        case .creation:
            "Не удалось сгенерировать GIF файл"
        }
    }
}

struct GIFGenerator {

    func generate(at url: URL, frames: [UIImage], animationSpeed: AnimationSpeed) throws {
        guard let fileGIF = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            throw GIFGeneratorError.creation
        }

        let metadata = [
            kCGImagePropertyGIFDictionary : [
                kCGImagePropertyGIFLoopCount : 0
            ]
        ]

        let delay: Double
        switch animationSpeed.option {
        case .total:
            delay = animationSpeed.duration / Double(frames.count)
        case .frame:
            delay = animationSpeed.duration
        }

        let frameMetadata = [
            kCGImagePropertyGIFDictionary : [
                kCGImagePropertyGIFDelayTime: delay
            ]
        ]

        CGImageDestinationSetProperties(fileGIF, metadata as CFDictionary)

        frames
            .compactMap { $0.cgImage }
            .forEach { CGImageDestinationAddImage(fileGIF, $0, frameMetadata as CFDictionary) }

        CGImageDestinationFinalize(fileGIF)
    }

}
