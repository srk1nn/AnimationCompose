//
//  BrushWidthSlider.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 02.11.2024.
//

import UIKit

final class BrushWidth {
    let min: CGFloat
    let max: CGFloat
    var current: CGFloat

    init(min: CGFloat, max: CGFloat, current: CGFloat) {
        self.min = min
        self.max = max
        self.current = current
    }

    func percent() -> CGFloat {
        return current / max
    }

    func update(percent: CGFloat) {
        let width = max * percent
        current = Swift.max(min, Swift.min(max, width))
    }
}

final class BrushWidthSlider: UIView {

    var brushWidth: BrushWidth? {
        didSet {
            applyBrushWidth()
        }
    }

    var onPercentChanged: ((CGFloat) -> Void)?

    private let gradientLayer = CAGradientLayer()
    private let trackLayer = CAShapeLayer()
    private let thumbView = UIView()
    private var isLayout = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(thumbChanged(_:)))
        thumbView.addGestureRecognizer(recognizer)

        gradientLayer.colors = [UIColor.brushStart.cgColor, UIColor.brushEnd.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = Constants.thumbCornerRadius
        thumbView.clipsToBounds = true

        layer.addSublayer(gradientLayer)
        addSubview(thumbView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !isLayout else {
            return
        }

        isLayout = true

        gradientLayer.frame = layer.bounds

        let path = UIBezierPath()
        let leftHeight = Constants.leftHeight
        let rightHeight = Constants.rightHeight
        let width = bounds.width
        let centerY = bounds.height / 2
        let leftRadius = leftHeight / 2
        let rightRadius = rightHeight / 2

        path.move(to: CGPoint(x: leftRadius, y: centerY - leftHeight / 2))
        path.addLine(to: CGPoint(x: leftRadius, y: centerY + leftHeight / 2))
        path.addLine(to: CGPoint(x: width - rightRadius, y: centerY + rightHeight / 2))
        path.addLine(to: CGPoint(x: width - rightRadius, y: centerY - rightHeight / 2))
        path.close()

        path.addArc(
            withCenter: CGPoint(x: leftRadius, y: centerY),
            radius: leftRadius,
            startAngle: .pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )

        path.addArc(
            withCenter: CGPoint(x: width - rightRadius, y: centerY),
            radius: rightRadius,
            startAngle: .pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: false
        )

        trackLayer.path = path.cgPath
        gradientLayer.mask = trackLayer

        let thumbSize = Constants.thumbSide

        thumbView.frame = CGRect(
            x: width - thumbSize / 2,
            y: (bounds.height - thumbSize) / 2,
            width: thumbSize,
            height: thumbSize
        )
    }

    @objc private func thumbChanged(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .changed:
            let location = sender.location(in: self)
            let availableWidth = bounds.width - Constants.thumbPadding

            if Constants.thumbPadding.isLess(than: location.x) && location.x.isLessThanOrEqualTo(availableWidth) {
                let percent = location.x / availableWidth
                thumbView.center = CGPoint(x: location.x, y: thumbView.center.y)
                onPercentChanged?(percent)
            }
        default:
            break
        }
    }

    private func applyBrushWidth() {
        guard let brushWidth else {
            return
        }

        let percent = brushWidth.percent()
        let availableWidth = bounds.width - Constants.thumbPadding
        let centerX = availableWidth * percent
        thumbView.center = CGPoint(x: centerX, y: thumbView.center.y)
    }

    private enum Constants {
        static let leftHeight: CGFloat = 8
        static let rightHeight: CGFloat = 18
        static let thumbPadding: CGFloat = 7
        static let thumbSide: CGFloat = 26
        static let thumbCornerRadius: CGFloat = 13
    }
}

