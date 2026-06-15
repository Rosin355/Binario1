//
//  BoardTypeSegmentedControl.swift
//  Binario1
//
//  Amber-on-black segmented control for Partenze / Arrivi. Custom-built to
//  keep the board identity (no default iOS segmented styling).
//

import SwiftUI

struct BoardTypeSegmentedControl: View {
    let selected: BoardType
    let onSelect: (BoardType) -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 6) {
            ForEach(BoardType.allCases) { type in
                segment(type)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BoardColors.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BoardColors.gridLine.opacity(0.6), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func segment(_ type: BoardType) -> some View {
        let isOn = type == selected
        Button {
            onSelect(type)
        } label: {
            Text(type.titleKey)
                .font(BoardFont.text(13, .bold))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOn ? BoardColors.amberBright : BoardColors.amberDim)
                .ledGlow(BoardColors.amber, radius: isOn ? 2 : 0, opacity: isOn ? 0.3 : 0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(red: 0.275, green: 0.149, blue: 0.0))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(BoardColors.amber.opacity(0.4), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "seg", in: indicator)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    BoardTypeSegmentedControl(selected: .departures, onSelect: { _ in })
        .padding()
        .background(BoardColors.background)
}
