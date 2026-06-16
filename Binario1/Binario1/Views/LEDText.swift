//
//  LEDText.swift
//  Binario1
//
//  Reusable amber railway-LED text: a plain SwiftUI `Text` base (always visible)
//  with glow + a fail-safe masked dark-dot grid for the dot-matrix feel. Same
//  reliable technique as the station title, factored out for the Viaggi board
//  title, LED clock times and platform digits. Never a Canvas-only renderer that
//  could draw empty.
//

import SwiftUI

struct LEDText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .heavy
    var color: Color = BoardColors.amber
    var glow: Double = 0.5
    var dotOpacity: Double = 0.42
    var tracking: CGFloat = 0
    /// Set true for dynamic NUMERIC values (times/platforms) to roll digits on
    /// change. Leave false for the static board title. No-op under Reduce Motion.
    var animatesNumeric: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var font: Font { .system(size: size, weight: weight, design: .monospaced) }
    private var transition: ContentTransition {
        animatesNumeric && !reduceMotion ? .numericText(value: BoardNumber.value(from: text)) : .identity
    }

    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(color)
            .lineLimit(1)
            .contentTransition(transition)
            .shadow(color: color.opacity(glow), radius: size * 0.085)
            .shadow(color: color.opacity(glow * 0.4), radius: size * 0.2)
            .overlay { dots }
            .accessibilityHidden(true)
    }

    /// Dark-dot grid masked to the glyphs → LED matrix look. Additive: if it does
    /// not draw, the underlying amber text stays fully visible.
    private var dots: some View {
        Canvas { ctx, sz in
            let gap = max(2.4, size / 11)
            let d = gap * 0.42
            var y: CGFloat = 0
            while y < sz.height {
                var x: CGFloat = 0
                while x < sz.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                             with: .color(BoardColors.background))
                    x += gap
                }
                y += gap
            }
        }
        .mask { Text(text).font(font).tracking(tracking) }
        .opacity(dotOpacity)
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        LEDText(text: "VIAGGI", size: 40)
        HStack(spacing: 16) {
            LEDText(text: "17:45", size: 34)
            LEDText(text: "6", size: 44, color: BoardColors.amberBright)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(BoardColors.background)
}
