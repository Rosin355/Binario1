//
//  TripsHeaderView.swift
//  Binario1
//
//  Viaggi header matching the design: "Binario [1]" brand lockup top-left, a
//  circular search button top-right, a large LED dot-matrix "VIAGGI" title, and a
//  subtitle with an "Aggiornato HH:mm ●" status on the right.
//

import SwiftUI

struct TripsHeaderView: View {
    var lastUpdated: Date?
    var onSearch: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1 — brand + search
            HStack(alignment: .center) {
                brandLockup
                Spacer(minLength: 8)
                searchButton
            }

            // Row 2 — LED board title (hero weight)
            LEDText(text: titleText, size: 42, color: BoardColors.ledPrimary, glow: 0.55)
                .accessibilityElement()
                .accessibilityLabel(Text("trips.title"))

            // Row 3 — subtitle + last-updated (single line, like the mockup)
            HStack(alignment: .firstTextBaseline) {
                Text("trips.subtitle")
                    .font(BoardFont.text(13))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 10)
                updatedLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: String { String(localized: "trips.title").uppercased() }

    private var brandLockup: some View {
        HStack(spacing: 6) {
            Text("app.name.word")                 // "Binario"
                .font(BoardFont.text(17, .semibold))
                .foregroundStyle(BoardColors.amber)
            Text(verbatim: "1")
                .font(BoardFont.digits(15, .bold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(BoardColors.amber.opacity(0.85), lineWidth: 1.5)
                )
        }
        .accessibilityElement(children: .combine)
    }

    private var searchButton: some View {
        Button { onSearch?() } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 42, height: 42)
                .background(
                    Circle().stroke(BoardColors.amber.opacity(0.55), lineWidth: 1.3)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("action.search"))
    }

    @ViewBuilder
    private var updatedLabel: some View {
        if let lastUpdated {
            HStack(spacing: 6) {
                Text(String(format: String(localized: "label.updatedAt"),
                            BoardFormatters.clock(lastUpdated)))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(BoardColors.amberDim)
                    .lineLimit(1)
                Circle()
                    .fill(BoardColors.amber)
                    .frame(width: 6, height: 6)
                    .ledGlow(BoardColors.amber, radius: 3, opacity: 0.7)
                    .accessibilityHidden(true)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    TripsHeaderView(lastUpdated: Date(), onSearch: {})
        .padding()
        .background(BoardColors.background)
}
