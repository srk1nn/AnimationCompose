//
//  Buttons.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class SecondaryButton: UIButton {
    override var isEnabled: Bool {
        didSet {
            tintColor = isEnabled ? .details : .disabled
        }
    }
}

final class PrimaryButton: UIButton {
    override var isSelected: Bool {
        didSet {
            tintColor = isSelected ? .selected : .details
        }
    }
}

final class BorderButton: UIButton {
    override var isSelected: Bool {
        didSet {
            layer.cornerRadius = bounds.width / 2
            layer.borderWidth = isSelected ? 1.5 : 0
            layer.borderColor = UIColor.selected.cgColor
        }
    }
}
