//
//  MainViewController.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit
import SwiftUI

struct MainViewModel {
    let canPlay: Bool
    let animation: Animation
    let animationSpeed: AnimationSpeed
    let canUndo: Bool
    let canRedo: Bool
    let canRemoveLayer: Bool
    let tool: Tool
    let color: UIColor
    let layer: Layer
    let previousLayer: Layer?
}

final class MainViewController: UIViewController {
    private let presenter = MainPresenter()
    private var animationSpeed: AnimationSpeed?
    private var onDismissShot: (() -> Void)?

    var mainView: MainView {
        view as! MainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: remove me
        UserDefaults.standard.removeObject(forKey: "animation.compose.show-tip")

        let recognizer = DrawingGestureRecognizer(target: presenter, action: #selector(MainPresenter.handleDrawing(_:)))
        recognizer.cancelsTouchesInView = false
        mainView.drawingView.addGestureRecognizer(recognizer)

        presenter.view = self
        presenter.didLoadView()
    }

    func apply(_ viewModel: MainViewModel) {
        switch viewModel.animation {
        case .idle:
            mainView.undoButton.isEnabled = viewModel.canUndo
            mainView.redoButton.isEnabled = viewModel.canRedo

            mainView.pauseButton.isEnabled = false
            mainView.playButton.isEnabled = viewModel.canPlay

            mainView.removeLayerButton.isEnabled = viewModel.canRemoveLayer

            [mainView.pencilButton,
             mainView.brushButton,
             mainView.eraseButton,
             mainView.instrumentsButton].forEach { $0?.isSelected = false }

            switch viewModel.tool {
            case .pencil:
                mainView.pencilButton.isSelected = true
            case .brush:
                mainView.brushButton.isSelected = true
            case .eraser:
                mainView.eraseButton.isSelected = true
            case .instruments:
                mainView.instrumentsButton.isSelected = true
            }

            mainView.colorButton.tintColor = viewModel.color

            mainView.previousDrawingView.drawingLayer = viewModel.previousLayer
            mainView.drawingView.drawingLayer = viewModel.layer

            stopAnimating()

        case .animating(let images):
            mainView.pauseButton.isEnabled = true
            mainView.playButton.isEnabled = false

            startAnimating(images: images, animationSpeed: viewModel.animationSpeed)
        }

        animationSpeed = viewModel.animationSpeed

        // State always changes due to user interactions
        // So we can always hides color panel here
        hideColorPanel()
    }

    func showAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let isAnimating = mainView.animationImageView.isAnimating

        let action = UIAlertAction(title: "OK", style: .default) { _ in
            if isAnimating {
                self.mainView.animationImageView.startAnimating()
            }
        }

        alert.addAction(action)

        present(alert, animated: true) {
            if isAnimating {
                self.mainView.animationImageView.stopAnimating()
            }
        }
    }

    // Shows only when animating
    func showShare(item: URL) {
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        activity.completionWithItemsHandler = { _, _, _, _ in
            self.mainView.animationImageView.startAnimating()
        }

        present(activity, animated: true) {
            self.mainView.animationImageView.stopAnimating()
        }
    }

    // MARK: - Undo & Redo

    @IBAction private func undoTapped(_ sender: UIButton) {
        presenter.undo()
    }

    @IBAction private func redoTapped(_ sender: UIButton) {
        presenter.redo()
    }

    // MARK: - Brashes

    @IBAction private func pencilTapped(_ sender: UIButton) {
        presenter.select(tool: .pencil)
    }

    @IBAction private func brushTapped(_ sender: UIButton) {
        presenter.select(tool: .brush)
    }

    @IBAction private func eraseTapped(_ sender: UIButton) {
        presenter.select(tool: .eraser)
    }

    // MARK: - Colors Selection

    @IBAction private func colorTapped(_ sender: UIButton) {
        sender.isSelected ? hideColorPanel() : showColorPanel()
    }

    @IBAction private func whiteTapped(_ sender: UIButton) {
        presenter.select(color: sender.tintColor)
    }

    @IBAction private func redTapped(_ sender: UIButton) {
        presenter.select(color: sender.tintColor)
    }

    @IBAction private func blackTapped(_ sender: UIButton) {
        presenter.select(color: sender.tintColor)
    }

    @IBAction private func blueTapped(_ sender: UIButton) {
        presenter.select(color: sender.tintColor)
    }

    @IBAction private func paletteTapped(_ sender: UIButton) {
        let colorPicker = UIColorPickerViewController()
        colorPicker.supportsAlpha = false
        colorPicker.delegate = self
        colorPicker.selectedColor = mainView.colorButton.tintColor
        colorPicker.presentationController?.delegate = self

        onDismissShot = {
            self.hideColorPanel()
        }

        present(colorPicker, animated: true)
    }

    // // MARK: - Layers

    @IBAction private func removeLayerTapped(_ sender: UIButton) {
        presenter.removeLayer()
    }

    @IBAction private func addLayerTapped(_ sender: UIButton) {
        presenter.addLayer()
    }
    
    @IBAction private func layersTapped(_ sender: UIButton) {
        guard let animatic = storyboard?.instantiateViewController(withIdentifier: "animatic") as? AnimaticViewController else {
            return
        }

        onDismissShot = {
            self.presenter.invalidateState()
        }

        animatic.onDismiss = { [weak self] in
            self?.onDismissShot?()
            self?.onDismissShot = nil
        }

        animatic.canvas = mainView.canvasView.bounds

        let navigation = UINavigationController(rootViewController: animatic)
        navigation.presentationController?.delegate = self
        present(navigation, animated: true)
    }

    // MARK: - Play & Pause

    @IBAction private func playTapped(_ sender: UIButton) {
        presenter.play(canvas: mainView.canvasView.bounds)
    }

    @IBAction private func pauseTapped(_ sender: UIButton) {
        presenter.pause()
    }

    @IBAction func shareTapped(_ sender: UIButton) {
        presenter.shareGIF()
    }

    // Shows only when animating
    @IBAction func speedTapped(_ sender: UIButton) {
        guard var animationSpeed else {
            return
        }

        mainView.animationImageView.stopAnimating()

        onDismissShot = { [self] in
            presenter.updateSpeed(animationSpeed)
            // Don't call start startAnimating
            // Because startAnimating will be call by MainPresenter.updateUI
        }

        let view = AnimationSpeedView(
            animationSpeed: animationSpeed,
            onSelect: { new in
                animationSpeed = new
            },
            onDismiss: { [weak self] in
                self?.onDismissShot?()
                self?.onDismissShot = nil
            }
        )

        let speedController = UIHostingController(rootView: view)

        speedController.presentationController?.delegate = self
        (speedController.presentationController as? UISheetPresentationController)?.detents = [.medium()]

        present(speedController, animated: true)
    }
    
    // MARK: - Private

    private func startAnimating(images: [UIImage], animationSpeed: AnimationSpeed) {
        mainView.drawingViews.forEach { $0.isHidden = true }
        mainView.animationViews.forEach { $0.isHidden = false }

        switch animationSpeed.option {
        case .total:
            mainView.animationImageView.animationDuration = animationSpeed.duration
        case .frame:
            mainView.animationImageView.animationDuration = Double(images.count) * animationSpeed.duration
        }

        mainView.animationImageView.animationImages = images
        mainView.animationImageView.startAnimating()
    }

    private func stopAnimating() {
        guard mainView.animationImageView.isAnimating else {
            return
        }

        mainView.animationImageView.stopAnimating()
        mainView.animationImageView.animationImages = nil

        mainView.animationViews.forEach { $0.isHidden = true }
        mainView.drawingViews.forEach { $0.isHidden = false }
    }

    private func showColorPanel() {
        mainView.colorButton.isSelected = true
        mainView.colorView.isHidden = false
    }

    private func hideColorPanel() {
        mainView.colorButton.isSelected = false
        mainView.colorView.isHidden = true
    }
}

extension MainViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        presenter.select(color: color)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        hideColorPanel()
    }
}

extension MainViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        onDismissShot?()
        onDismissShot = nil
    }
}