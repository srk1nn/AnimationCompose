//
//  Collection+Safe.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 29.10.2024.
//

import Foundation

extension Collection {

    subscript(safe index: Index) -> Element? {
        guard index >= startIndex, index < endIndex else {
            return nil
        }
        return self[index]
    }
}
