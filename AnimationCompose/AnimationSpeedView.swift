//
//  AnimationSpeedView.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 29.10.2024.
//

import SwiftUI

enum AnimationSpeedOption: CaseIterable {
    case total
    case frame

    var name: String {
        switch self {
        case .total:
            "Общая"
        case .frame:
            "Кадра"
        }
    }
}

struct AnimationSpeed {
    let option: AnimationSpeedOption
    let duration: TimeInterval
}

struct AnimationSpeedView: View {
    @Environment(\.dismiss) private var dismiss
    private let onSelect: (AnimationSpeed) -> Void
    private let onDismiss: () -> Void

    @State private var option: AnimationSpeedOption
    @State private var duration: TimeInterval

    init(
        animationSpeed: AnimationSpeed,
        onSelect: @escaping (AnimationSpeed) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _option = State(initialValue: animationSpeed.option)
        _duration = State(initialValue: animationSpeed.duration)
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            List {
                Picker("Длительность", selection: $option) {
                    ForEach(AnimationSpeedOption.allCases, id: \.self) {
                        Text($0.name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: option) { _ in
                    onSelect(animationSpeed())
                }

                HStack {
                    Text("Секунд")
                    Spacer()
                    TextField("", value: $duration, formatter: NumberFormatter.seconds)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 75)
                        .onChange(of: duration) { new in
                            guard
                                let str = NumberFormatter.seconds.string(from: new as NSNumber),
                                let number = NumberFormatter.seconds.number(from: str)
                            else {
                                return
                            }

                            duration = number.doubleValue
                            onSelect(animationSpeed())
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("Скорость анимации")
            .toolbar {
                Button {
                    dismiss()
                    onDismiss()
                } label: {
                    Circle()
                        .fill(Color(uiColor: .systemGray5))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        )
                }
            }
        }
    }

    private func animationSpeed() -> AnimationSpeed {
        AnimationSpeed(option: option, duration: duration)
    }
}

private extension NumberFormatter {
    static let seconds: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumIntegerDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        return formatter
    }()
}

#Preview {
    AnimationSpeedView(
        animationSpeed: AnimationSpeed(
            option: .total,
            duration: 1
        ),
        onSelect: { _ in },
        onDismiss: { }
    )
}
