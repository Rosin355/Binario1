//
//  JourneyPlatformBadgeView.swift
//  Binario1
//
//  Platform / binario for Viaggi: a small "BINARIO / PLATFORM" caption above a
//  large LED dot-matrix digit (no box), matching the design reference. The board
//  digit is rendered with the reusable `LEDText` so it reads as an LED segment.
//

import SwiftUI

struct JourneyPlatformBadgeView: View {
    let platform: String?
    var numberSize: CGFloat = 24
    var captionSize: CGFloat = 8
    var color: Color = BoardColors.platform
    var alignment: HorizontalAlignment = .leading

    private var value: String { platform?.isEmpty == false ? platform! : "--" }

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("journey.platform")            // "Binario" / "Platform"
                .font(BoardFont.text(captionSize, .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amberDim)
            LEDText(text: value, size: numberSize, color: color, glow: 0.5)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 24) {
        JourneyPlatformBadgeView(platform: "2")
        JourneyPlatformBadgeView(platform: "6", numberSize: 46, color: BoardColors.amberBright, alignment: .center)
        JourneyPlatformBadgeView(platform: "5", numberSize: 16, alignment: .trailing)
    }
    .padding()
    .background(BoardColors.background)
}
