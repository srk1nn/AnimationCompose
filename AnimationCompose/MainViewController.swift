//
//  MainViewController.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit
import SwiftUI

struct MainViewModel {
    let isAnimating: Bool
    let canUndo: Bool
    let canRedo: Bool
    let canPlay: Bool
    let canRemoveLayer: Bool
    let isGeneratingGIF: Bool
    let hasHitches: Bool
    let tool: Tool
    let color: UIColor
    let layer: Layer
    let previousLayer: Layer?
}

final class MainViewController: UIViewController {
    private let presenter = MainPresenter()
    private var onDismissShot: (() -> Void)?

    private var mainView: MainView {
        view as! MainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mainView.brushWidthSlider.onPercentChanged = {
            self.presenter.updateWidth(percent: $0)
        }

        let recognizer = DrawingGestureRecognizer(target: presenter, action: #selector(MainPresenter.handleDrawing(_:)))
        recognizer.cancelsTouchesInView = false
        mainView.drawingView.addGestureRecognizer(recognizer)

        presenter.view = self
        presenter.didLoadView()
    }

    func apply(_ viewModel: MainViewModel) {
        if viewModel.isAnimating {
            mainView.drawingViews.forEach { $0.isHidden = true }
            mainView.animationViews.forEach { $0.isHidden = false }

            mainView.playButton.isEnabled = false
            mainView.pauseButton.isEnabled = true

            mainView.hitchesButton.isHidden = !viewModel.hasHitches
        } else {
            mainView.animationViews.forEach { $0.isHidden = true }
            mainView.drawingViews.forEach { $0.isHidden = false }

            mainView.undoButton.isEnabled = viewModel.canUndo
            mainView.redoButton.isEnabled = viewModel.canRedo

            mainView.pauseButton.isEnabled = false
            mainView.playButton.isEnabled = viewModel.canPlay

            mainView.removeLayerButton.isEnabled = viewModel.canRemoveLayer

            [mainView.pencilButton,
             mainView.brushButton,
             mainView.eraseButton].forEach { $0?.isSelected = false }

            switch viewModel.tool {
            case .pencil:
                mainView.pencilButton.isSelected = true
            case .brush:
                mainView.brushButton.isSelected = true
            case .eraser:
                mainView.eraseButton.isSelected = true
            }

            mainView.colorButton.tintColor = viewModel.color

            mainView.previousDrawingView.drawingLayer = viewModel.previousLayer
            mainView.drawingView.drawingLayer = viewModel.layer
        }

        if viewModel.isGeneratingGIF {
            mainView.shareButton.showActivity()
        } else {
            mainView.shareButton.hideActivity()
        }

        // State always changes due to user interactions
        // So we can always hides color panel here
        hideColorPanel()
        hideBrushWidth()
    }

    // MARK: - Routing

    func showAlert(title: String, message: String? = nil, completion: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let action = UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        }

        alert.addAction(action)
        present(alert, animated: true)
    }

    func showShare(item: URL) {
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        (activity.presentationController as? UISheetPresentationController)?.detents = [.large()]

        activity.completionWithItemsHandler = { [self] _, _, _, _ in
            presenter.shareDidClose()
        }

        present(activity, animated: true) { [self] in
            presenter.shareDidShown()
        }
    }

    func showAnimationSpeed(_ current: AnimationSpeed) {
        var animationSpeed = current

        onDismissShot = { [self] in
            presenter.animationSpeedDidSelect(animationSpeed)
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
        present(speedController, animated: true) { [self] in
            presenter.speedDidShown()
        }
    }

    func showAnimationCreation() {
        let alert = UIAlertController(title: "Создание анимации", message: "Введите количество кадров", preferredStyle: .alert)
        alert.addTextField {
            $0.keyboardType = .numberPad
        }

        let create = UIAlertAction(title: "Создать", style: .default) { [weak alert, self] _ in
            let textField = alert?.textFields?.first
            let count = textField?.text.flatMap { Int($0) }
            count.map {
                presenter.animationCreationDidSelect(framesCount: $0, canvas: mainView.canvasView.bounds)
            }
        }

        let cancel = UIAlertAction(title: "Отмена", style: .cancel)

        alert.addAction(create)
        alert.addAction(cancel)

        present(alert, animated: true)
    }

    func showAnimatic() {
        guard let animatic = storyboard?.instantiateViewController(withIdentifier: "animatic") as? AnimaticViewController else {
            return
        }

        onDismissShot = { [self] in
            presenter.animaticDidClose()
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

    func showPallete() {
        let colorPicker = UIColorPickerViewController()
        colorPicker.supportsAlpha = false
        colorPicker.delegate = self
        colorPicker.selectedColor = mainView.colorButton.tintColor
        colorPicker.presentationController?.delegate = self

        present(colorPicker, animated: true) {
            self.hideColorPanel()
        }
    }
}

// MARK: - Actions

extension MainViewController {

    // MARK: - Undo & Redo

    @IBAction private func undoTapped(_ sender: UIButton) {
        presenter.undo()
    }

    @IBAction private func redoTapped(_ sender: UIButton) {
        presenter.redo()
    }

    // MARK: - Brashes

    @IBAction private func pencilTapped(_ sender: UIButton) {
        if sender.isSelected {
            toggleBrushWidth()
        } else {
            presenter.select(tool: .pencil)
        }
    }

    @IBAction private func brushTapped(_ sender: UIButton) {
        if sender.isSelected {
            toggleBrushWidth()
        } else {
            presenter.select(tool: .brush)
        }
    }

    @IBAction private func eraseTapped(_ sender: UIButton) {
        if sender.isSelected {
            toggleBrushWidth()
        } else {
            presenter.select(tool: .eraser)
        }
    }

    @IBAction func instrumentsTapped(_ sender: UIButton) {
        presenter.createAnimation()
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
        presenter.handlePalette()
    }

    // // MARK: - Layers

    @IBAction private func removeLayerTapped(_ sender: UIButton) {
        presenter.removeLayer()
    }

    @IBAction private func addLayerTapped(_ sender: UIButton) {
        presenter.addLayer()
    }

    @IBAction private func layersTapped(_ sender: UIButton) {
        presenter.handleLayers()
    }

    // MARK: - Play & Pause

    @IBAction private func playTapped(_ sender: UIButton) {
        presenter.playAnimation(in: mainView.animationImageView, canvas: mainView.canvasView.bounds)
    }

    @IBAction private func pauseTapped(_ sender: UIButton) {
        presenter.stopAnimation()
    }

    @IBAction func shareTapped(_ sender: UIButton) {
        presenter.shareGIF(canvas: mainView.canvasView.bounds)
    }

    @IBAction func speedTapped(_ sender: UIButton) {
        presenter.handleSpeed()
    }

    @IBAction func hitchesTapped(_ sender: UIButton) {
        presenter.handleHitches()
    }
}

// MARK: - Private

private extension MainViewController {

    func showColorPanel() {
        hideBrushWidth()
        mainView.colorButton.isSelected = true
        mainView.colorView.isHidden = false
    }

    func hideColorPanel() {
        mainView.colorButton.isSelected = false
        mainView.colorView.isHidden = true
    }

    func toggleBrushWidth() {
        if mainView.brushWidthView.isHidden {
            showBrushWidth()
        } else {
            hideBrushWidth()
        }
    }

    func showBrushWidth() {
        hideColorPanel()
        mainView.brushWidthSlider.brushWidth = presenter.brushWidth()
        mainView.brushWidthView.isHidden = false
    }

    func hideBrushWidth() {
        mainView.brushWidthView.isHidden = true
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension MainViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        presenter.select(color: color)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension MainViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        onDismissShot?()
        onDismissShot = nil
    }
}
