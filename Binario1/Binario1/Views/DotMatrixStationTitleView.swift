//
//  DotMatrixStationTitleView.swift
//  Binario1
//
//  Two-line amber railway-LED station title. Reliability first: every glyph is a
//  plain SwiftUI `Text` (always visible), amber/bold/monospaced + subtle glow,
//  with a fail-safe masked dot texture for the LED feel — no Canvas/ImageRenderer
//  base renderer that could render empty.
//
//  Reveal animation is DETERMINISTIC. A single `.task(id:)` drives a `revealed`
//  character count; each glyph turns on (light horizontal 3D flip, axis
//  (x:0, y:1, z:0)) as the count passes it. The loop always ends at the full
//  count and also snaps to full if cancelled, so the title can NEVER freeze on a
//  partial string (e.g. stuck at "P"). It restarts whenever `animationToken`
//  changes (entering the Partenze tab) or the station name changes — without an
//  `.id` remount or per-character tasks. Reduce Motion shows the full title at once.
//

import SwiftUI

struct DotMatrixStationTitleView: View {
    let stationName: String
    /// Bumped by the host (e.g. on Partenze tab entry) to replay the reveal.
    var animationToken: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    // Fixed slot counts give a stable width; unused slots hold a blank space.
    private let primarySlots = 9
    private let secondarySlots = 12

    private var title: (primary: String, secondary: String) {
        StationNameFormatter.boardTitle(for: stationName)
    }
    private var primaryRealCount: Int { min(title.primary.count, primarySlots) }
    private var secondaryRealCount: Int {
        title.secondary.isEmpty ? 0 : min(title.secondary.count, secondarySlots)
    }
    private var totalReal: Int { primaryRealCount + secondaryRealCount }

    /// Restart the reveal when the tab-entry token OR the station name changes.
    private var revealKey: String { "\(animationToken)|\(title.primary)|\(title.secondary)" }

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            line(slotted(title.primary, primarySlots), realCount: primaryRealCount,
                 globalOffset: 0, fontSize: 34, color: BoardColors.ledPrimary, glow: 0.55)
            if !title.secondary.isEmpty {
                line(slotted(title.secondary, secondarySlots), realCount: secondaryRealCount,
                     globalOffset: primaryRealCount, fontSize: 22, color: BoardColors.ledSecondary, glow: 0.40)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(stationName))
        .task(id: revealKey) { await runReveal() }
    }

    @MainActor
    private func runReveal() async {
        let total = totalReal
        guard total > 0 else { revealed = 0; return }
        if reduceMotion { revealed = total; return }   // no motion → full title at once
        revealed = 0
        for i in 1...total {
            try? await Task.sleep(for: .milliseconds(70))
            if Task.isCancelled { revealed = total; return }   // never leave it partial
            withAnimation(.snappy(duration: 0.22)) { revealed = i }
        }
        revealed = total                                       // guaranteed final state
    }

    @ViewBuilder
    private func line(_ chars: [Character], realCount: Int, globalOffset: Int,
                      fontSize: CGFloat, color: Color, glow: Double) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                // Padding slots (spaces) are always "on" (invisible anyway); real
                // glyphs turn on as the reveal count advances past their index.
                let on = idx >= realCount || (globalOffset + idx < revealed)
                LEDGlyph(char: ch, fontSize: fontSize, color: color, glow: glow, on: on)
            }
        }
    }

    private func slotted(_ text: String, _ slots: Int) -> [Character] {
        let arr = Array(text.uppercased())
        return (0..<slots).map { $0 < arr.count ? arr[$0] : " " }
    }
}

// MARK: - One LED glyph; turns on with a light 3D flip as the reveal reaches it.

private struct LEDGlyph: View {
    let char: Character
    let fontSize: CGFloat
    let color: Color
    let glow: Double
    let on: Bool

    private var font: Font { .system(size: fontSize, weight: .heavy, design: .monospaced) }

    var body: some View {
        Text(String(char))
            .font(font)
            .foregroundStyle(color)
            .shadow(color: color.opacity(glow), radius: 3)
            .shadow(color: color.opacity(glow * 0.4), radius: 7)
            .overlay { ledDots }
            .opacity(on ? 1 : 0)
            .rotation3DEffect(.degrees(on ? 0 : 90), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .accessibilityHidden(true)
    }

    /// Masked dark-dot grid for the LED feel; additive, so the glyph stays visible
    /// even if it doesn't draw.
    private var ledDots: some View {
        Canvas { ctx, size in
            let gap = max(2.6, fontSize / 11)
            let d = gap * 0.42
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                             with: .color(BoardColors.background))
                    x += gap
                }
                y += gap
            }
        }
        .mask { Text(String(char)).font(font) }
        .opacity(0.45)
        .allowsHitTesting(false)
    }
}

#Preview("Padova") {
    DotMatrixStationTitleView(stationName: "Padova")
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(BoardColors.background)
}

#Preview("Bologna") {
    DotMatrixStationTitleView(stationName: "Bologna Centrale")
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(BoardColors.background)
}
