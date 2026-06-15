//
//  PlatformBadgeView.swift
//  Binario1
//
//  The platform / binario in a bordered board box: big number plus an optional
//  small suffix ("OV", "EST"). The strongest, brightest element on each row.
//

import SwiftUI

struct PlatformBadgeView: View {
    let platform: String              // e.g. "7 OV", "3 EST", "11", "--"
    var highlighted: Bool = false
    var numberSize: CGFloat = 19

    private var number: String {
        platform.split(separator: " ").first.map(String.init) ?? platform
    }
    private var suffix: String {
        platform.split(separator: " ").dropFirst().joined(separator: " ")
    }
    private var isAssigned: Bool { platform != "--" && !platform.isEmpty }

    private var tint: Color { isAssigned ? BoardColors.platform : BoardColors.amberDim }
    private var borderColor: Color {
        highlighted ? BoardColors.amberBright : (isAssigned ? BoardColors.border : BoardColors.borderDim)
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(number)
                .font(BoardFont.digits(numberSize))
            if !suffix.isEmpty {
                Text(suffix)
                    .font(BoardFont.text(numberSize * 0.55, .semibold))
                    .foregroundStyle(BoardColors.amberDim)
                    .baselineOffset(-1)
            }
        }
        .foregroundStyle(tint)
        .ledGlow(BoardColors.platform, radius: isAssigned ? (highlighted ? 5 : 3) : 0,
                 opacity: isAssigned ? (highlighted ? 0.5 : 0.35) : 0)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 8)
        .frame(minWidth: 44, minHeight: 30)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(BoardColors.amber.opacity(highlighted ? 0.10 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor.opacity(highlighted ? 1 : 0.8), lineWidth: highlighted ? 1.3 : 1)
                )
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        PlatformBadgeView(platform: "6", highlighted: true)
        PlatformBadgeView(platform: "7 OV")
        PlatformBadgeView(platform: "3 EST")
        PlatformBadgeView(platform: "--")
    }
    .padding()
    .background(BoardColors.background)
}
