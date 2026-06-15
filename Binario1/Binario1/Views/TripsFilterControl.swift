//
//  TripsFilterControl.swift
//  Binario1
//
//  Amber-on-black segmented filter for Viaggi (Oggi / Salvati / Recenti). Mirrors
//  BoardTypeSegmentedControl to keep the board identity.
//

import SwiftUI

struct TripsFilterControl: View {
    let selected: TripsFilter
    let onSelect: (TripsFilter) -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TripsFilter.allCases) { filter in
                segment(filter)
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
    private func segment(_ filter: TripsFilter) -> some View {
        let isOn = filter == selected
        Button {
            onSelect(filter)
        } label: {
            Text(filter.titleKey)
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
                            .matchedGeometryEffect(id: "tripseg", in: indicator)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    TripsFilterControl(selected: .today, onSelect: { _ in })
        .padding()
        .background(BoardColors.background)
}
