//
//  JourneyPlatformBadgeView.swift
//  Binario1
//
//  Labeled platform badge for Viaggi cards: a small "BINARIO / PLATFORM" caption
//  above the reused board platform box, so the binario is very easy to scan.
//  Reuses PlatformBadgeView — no style duplication.
//

import SwiftUI

struct JourneyPlatformBadgeView: View {
    let platform: String?
    var highlighted: Bool = false
    var numberSize: CGFloat = 19

    private var value: String { platform?.isEmpty == false ? platform! : "--" }

    var body: some View {
        VStack(spacing: 2) {
            Text("journey.platform")            // "Binario" / "Platform"
                .font(BoardFont.text(8, .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BoardColors.amberDim)
            PlatformBadgeView(platform: value, highlighted: highlighted, numberSize: numberSize)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        JourneyPlatformBadgeView(platform: "2")
        JourneyPlatformBadgeView(platform: "6", highlighted: true, numberSize: 30)
        JourneyPlatformBadgeView(platform: nil)
    }
    .padding()
    .background(BoardColors.background)
}
