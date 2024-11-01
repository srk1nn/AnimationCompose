//
//  Buttons.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class SecondaryButton: UIButton {
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activity = UIActivityIndicatorView(style: .large)
        activity.hidesWhenStopped = true
        activity.frame = bounds
        activity.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(activity)
        return activity
    }()

    override var isEnabled: Bool {
        didSet {
            tintColor = isEnabled ? .details : .disabled
        }
    }

    func showActivity() {
        tintColor = .clear
        activityIndicator.startAnimating()
    }

    func hideActivity() {
        tintColor = isEnabled ? .details : .disabled
        activityIndicator.stopAnimating()
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
