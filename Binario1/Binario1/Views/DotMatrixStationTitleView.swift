//
//  DotMatrixStationTitleView.swift
//  Binario1
//
//  Two-line amber railway-LED station title. Reliability first: every glyph is a
//  plain SwiftUI `Text` (always visible), amber/bold/monospaced + subtle glow,
//  with a fail-safe masked dot texture on top for the LED feel — no Canvas/
//  ImageRenderer base renderer that could render empty.
//
//  On a STATION CHANGE each character does a lightweight horizontal 3D flip
//  (`rotation3DEffect` axis (x:0, y:1, z:0)), staggered by character index
//  (Double(index) * 0.1) — a railway-board refresh. The old glyph rotates to
//  edge-on, swaps while hidden, then the new glyph rotates back in, so there is
//  no mirror, no ghosting, and no blank title. Reduce Motion updates instantly.
//

import SwiftUI

struct DotMatrixStationTitleView: View {
    let stationName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Fixed slot counts give each character a stable identity (so changes flip in
    // place instead of inserting/removing). Unused slots hold a blank space →
    // invisible (no boxes), just stable width.
    private let primarySlots = 9
    private let secondarySlots = 12

    private var title: (primary: String, secondary: String) {
        StationNameFormatter.boardTitle(for: stationName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            FlipLine(text: title.primary, slots: primarySlots,
                     fontSize: 34, color: BoardColors.ledPrimary, glow: 0.55,
                     baseDelay: 0, animate: !reduceMotion)
            if !title.secondary.isEmpty {
                FlipLine(text: title.secondary, slots: secondarySlots,
                         fontSize: 22, color: BoardColors.ledSecondary, glow: 0.40,
                         baseDelay: 0.22, animate: !reduceMotion)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(stationName))
    }
}

// MARK: - One line of flipping characters

private struct FlipLine: View {
    let text: String
    var slots: Int
    var fontSize: CGFloat
    var color: Color
    var glow: Double
    var spacing: CGFloat = 1
    var baseDelay: Double = 0
    var animate: Bool

    private var chars: [Character] {
        let arr = Array(text.uppercased())
        return (0..<slots).map { $0 < arr.count ? arr[$0] : " " }
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<slots, id: \.self) { index in
                FlipCharacter(
                    target: chars[index],
                    fontSize: fontSize,
                    color: color,
                    glow: glow,
                    flipDelay: baseDelay + Double(index) * 0.1,
                    animate: animate
                )
            }
        }
    }
}

// MARK: - One character with a horizontal 3D flip on change

private struct FlipCharacter: View {
    let target: Character
    var fontSize: CGFloat
    var color: Color
    var glow: Double
    var flipDelay: Double
    var animate: Bool

    @State private var shown: Character = " "
    @State private var angle: Double = 0
    @State private var didAppear = false
    @State private var flip: Task<Void, Never>?

    private var font: Font { .system(size: fontSize, weight: .heavy, design: .monospaced) }

    var body: some View {
        glyph
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .onAppear { if !didAppear { shown = target; didAppear = true } }     // no flip on first show
            .onChange(of: target) { _, new in startFlip(to: new) }
            .onDisappear { flip?.cancel() }
    }

    private var glyph: some View {
        Text(String(shown))
            .font(font)
            .foregroundStyle(color)
            .shadow(color: color.opacity(glow), radius: 3)
            .shadow(color: color.opacity(glow * 0.4), radius: 7)
            .overlay { ledDots }
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
        .mask { Text(String(shown)).font(font) }
        .opacity(0.45)
        .allowsHitTesting(false)
    }

    private func startFlip(to new: Character) {
        guard animate else { shown = new; return }
        flip?.cancel()
        flip = Task { @MainActor in
            if flipDelay > 0 {
                try? await Task.sleep(for: .seconds(flipDelay))
                if Task.isCancelled { return }
            }
            // old glyph rotates to edge-on…
            withAnimation(.easeIn(duration: 0.12)) { angle = 90 }
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { shown = new; angle = 0; return }
            // …swap while hidden and jump to the other edge (no animation)…
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { shown = new; angle = -90 }
            // …new glyph rotates back into view (front-facing, never mirrored).
            withAnimation(.easeOut(duration: 0.12)) { angle = 0 }
        }
    }
}

#Preview("Bologna") {
    DotMatrixStationTitleView(stationName: "Bologna Centrale")
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(BoardColors.background)
}

#Preview("Reggio Emilia") {
    DotMatrixStationTitleView(stationName: "Reggio Emilia AV Mediopadana")
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(BoardColors.background)
}
