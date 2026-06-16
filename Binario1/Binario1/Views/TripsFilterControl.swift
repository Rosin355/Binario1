//
//  TripsFilterControl.swift
//  Binario1
//
//  Viaggi segmented filter (Oggi / Salvati / Recenti). Selected segment is a
//  bright amber→orange gradient pill with dark text (per the design); unselected
//  segments are dim amber on the dark track.
//

import SwiftUI

struct TripsFilterControl: View {
    let selected: TripsFilter
    let onSelect: (TripsFilter) -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TripsFilter.allCases) { filter in
                segment(filter)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(BoardColors.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(BoardColors.border.opacity(0.45), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func segment(_ filter: TripsFilter) -> some View {
        let isOn = filter == selected
        Button {
            withAnimation(.snappy(duration: 0.22)) { onSelect(filter) }
        } label: {
            Text(filter.titleKey)
                .font(BoardFont.text(13, .bold))
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOn ? BoardColors.background : BoardColors.amberDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [BoardColors.amberBright, BoardColors.amber],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(BoardColors.amberBright.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: BoardColors.amber.opacity(0.5), radius: 5, y: 1)
                            .matchedGeometryEffect(id: "tripseg", in: indicator)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    VStack(spacing: 16) {
        TripsFilterControl(selected: .today, onSelect: { _ in })
        TripsFilterControl(selected: .saved, onSelect: { _ in })
    }
    .padding()
    .background(BoardColors.background)
}
