//
//  AnimaticViewController.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 29.10.2024.
//

import UIKit

final class AnimaticCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var tipView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var drawingView: DrawingView!
}

final class AnimaticViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var removeBarButton: UIBarButtonItem!

    private let layerManager: LayerManager = .shared
    private var cellSize: CGSize = .zero

    var onDismiss: (() -> Void)?
    var canvas: CGRect = .zero

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.isPagingEnabled = false

        collectionView.contentInset = UIEdgeInsets(
            top: Constants.padding,
            left: Constants.padding,
            bottom: 0,
            right: Constants.padding
        )

        collectionView.dataSource = self
        collectionView.delegate = self

        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.2
        collectionView.addGestureRecognizer(recognizer)

        removeBarButton.menu = UIMenu(children: [
            UIAction(title: "Удалить все", image: UIImage(systemName: "xmark"), attributes: .destructive, handler: { [weak self] _ in
                self?.layerManager.removeAllLayers()
                self?.collectionView.reloadData()
            })
        ])

        let ratio = canvas.height / canvas.width
        let availableWidth = UIScreen.main.bounds.width - Constants.padding * 2 - Constants.spacing
        let cellWidth = floor(availableWidth / 2)
        let cellHeight = cellWidth * ratio
        cellSize = .init(width: cellWidth, height: cellHeight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.handleShowTip(animated: true)
        }
    }

    // TODO: подумать
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        if isTipShown() {
//            view.layoutIfNeeded()
//            let indexPath = IndexPath(item: layerManager.index(), section: 0)
//            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
//        }
//    }
//
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//
//        if !isTipShown() {
//            let indexPath = IndexPath(item: layerManager.index(), section: 0)
//            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
//        }
//    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        handleShowTip()
    }

    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            let location = sender.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                if indexPath.item == 0 {
                    handleShowTip()
                }
                collectionView.beginInteractiveMovementForItem(at: indexPath)
            }
        case .changed:
            let location = sender.location(in: collectionView)
            collectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }

    @IBAction private func closeTapped(_ sender: UIBarButtonItem) {
        onDismiss?()
        dismiss(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return layerManager.allLayers().count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? AnimaticCollectionViewCell else {
            return UICollectionViewCell()
        }

        let layer = layerManager.allLayers()[indexPath.item]

        cell.numberLabel.text = "\(indexPath.item + 1)"
        cell.drawingView.relativeToCanvas = canvas
        cell.drawingView.drawingLayer = layer
        cell.tipView.isHidden = !shouldShowTip(for: indexPath)
        cell.contentView.layer.borderColor = UIColor.selected.cgColor
        cell.contentView.layer.borderWidth = (layer === layerManager.currentLayer()) ? 5 : 0

        cell.moreButton.menu = UIMenu(children: [
            UIAction(title: "Дублировать", image: UIImage(systemName: "square.2.layers.3d"), handler: { [weak self] _ in
                guard let self else {
                    return
                }

                let newLayer = Layer(layer: layer)
                let success = layerManager.insertLayer(newLayer, at: indexPath.item)

                if success {
                    collectionView.insertItems(at: [indexPath])
                    reconfigureCells()
                } else {
                    showAlert(title: "Ошибка", message: "Превышено максимальное количество кадров")
                }
            }),
            UIAction(title: "Удалить", image: UIImage(systemName: "xmark"), attributes: .destructive, handler: { [weak self] _ in
                guard let self else {
                    return
                }

                layerManager.removeLayer(at: indexPath.item)
                let layers = layerManager.allLayers()

                if layers.count == 1 {
                    self.collectionView.reloadData()
                } else {
                    collectionView.deleteItems(at: [indexPath])
                    reconfigureCells()
                }
            })
        ])

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        layerManager.selectLayer(at: indexPath.item)
        onDismiss?()
        dismiss(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        layerManager.moveLayers(from: sourceIndexPath.item, to: destinationIndexPath.item)
        reconfigureCells()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return Constants.spacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return Constants.spacing
    }

    private func reconfigureCells() {
        let indexPaths = stride(
            from: 0,
            to: layerManager.allLayers().count,
            by: 1
        ).map { IndexPath(item: $0, section: 0) }

        collectionView.reconfigureItems(at: indexPaths)
    }

    private func isTipShown() -> Bool {
        UserDefaults.standard.bool(forKey: Constants.showTipKey)
    }

    private func shouldShowTip(for indexPath: IndexPath) -> Bool {
        indexPath.item == 0 && !isTipShown()
    }

    private func handleShowTip(animated: Bool = false) {
        let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? AnimaticCollectionViewCell
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                cell?.tipView.alpha = 0
            }, completion: { _ in
                cell?.tipView.isHidden = true
            })
        } else {
            cell?.tipView.isHidden = true
        }
        UserDefaults.standard.setValue(true, forKey: Constants.showTipKey)
    }

    private func showAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }

    private enum Constants {
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 16
        static let showTipKey = "animation.compose.show-tip"
    }
}
