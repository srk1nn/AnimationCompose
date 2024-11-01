//
//  MainView.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class MainView: UIView {
    @IBOutlet weak var undoButton: SecondaryButton!
    @IBOutlet weak var redoButton: SecondaryButton!

    @IBOutlet weak var removeLayerButton: UIButton!
    @IBOutlet weak var addLayerButton: UIButton!
    @IBOutlet weak var layersButton: UIButton!

    @IBOutlet weak var shareButton: SecondaryButton!
    @IBOutlet weak var speedButton: SecondaryButton!
    @IBOutlet weak var pauseButton: SecondaryButton!
    @IBOutlet weak var playButton: SecondaryButton!

    @IBOutlet weak var canvasView: UIImageView!
    @IBOutlet weak var animationImageView: UIImageView!
    @IBOutlet weak var previousDrawingView: DrawingView!
    @IBOutlet weak var drawingView: DrawingView!

    @IBOutlet weak var pencilButton: PrimaryButton!
    @IBOutlet weak var brushButton: PrimaryButton!
    @IBOutlet weak var eraseButton: PrimaryButton!
    @IBOutlet weak var instrumentsButton: PrimaryButton!
    @IBOutlet weak var colorButton: BorderButton!

    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var paletteButton: SecondaryButton!
    @IBOutlet weak var whiteColorButton: BorderButton!
    @IBOutlet weak var redColorButton: BorderButton!
    @IBOutlet weak var blackColorButton: BorderButton!
    @IBOutlet weak var blueColorButton: BorderButton!

    var drawingViews: [UIView] {
        [undoButton,
         redoButton,
         removeLayerButton,
         addLayerButton,
         layersButton,
         pencilButton,
         brushButton,
         eraseButton,
         instrumentsButton,
         colorButton,
         colorView,
         drawingView,
         previousDrawingView]
    }

    var animationViews: [UIView] {
        [animationImageView, shareButton, speedButton]
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            colorView.layer.borderColor = UIColor.systemGray2.cgColor
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    private func setup() {
        setupColorView()
    }

    private func setupColorView() {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blur = UIVisualEffectView(effect: effect)
        blur.frame = canvasView.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorView.insertSubview(blur, at: 0)

        colorView.layer.cornerRadius = 4
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.systemGray2.cgColor

        colorView.isHidden = true
    }
}
