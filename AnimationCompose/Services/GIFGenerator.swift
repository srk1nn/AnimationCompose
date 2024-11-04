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
    case cancelled

    var errorDescription: String? {
        switch self {
        case .creation:
            "Не удалось сгенерировать GIF файл"
        case .cancelled:
            "Генерация была отменена"
        }
    }
}

struct GIFGenerator {
    private let renderer = Renderer()
    private let fileManager = FileManager.default

    func generate(at url: URL, layers: [Layer], background: UIImage, canvas: CGRect, animationSpeed: AnimationSpeed, isCancelled: () -> Bool) throws {
        guard let fileGIF = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, layers.count, nil) else {
            throw GIFGeneratorError.creation
        }

        let metadata = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0,
                kCGImagePropertyGIFHasGlobalColorMap: false
            ]
        ]

        let delay = animationSpeed.secondsPerFrame(framesCount: layers.count)

        let frameMetadata = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFUnclampedDelayTime: delay
            ]
        ]

        CGImageDestinationSetProperties(fileGIF, metadata as CFDictionary)

        for layer in layers {
            try autoreleasepool {
                guard !isCancelled() else {
                    throw GIFGeneratorError.cancelled
                }

                let image = renderer.renderImage(layer: layer, background: background, canvas: canvas)
                let url = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")

                guard
                    let data = image.jpegData(compressionQuality: 0.7),
                    let _ = try? data.write(to: url),
                    let source = CGImageSourceCreateWithURL(url as CFURL, nil)
                else {
                    return
                }

                CGImageDestinationAddImageFromSource(fileGIF, source, 0, frameMetadata as CFDictionary)
                try? fileManager.removeItem(at: url)
            }
        }

        CGImageDestinationFinalize(fileGIF)
    }

}
