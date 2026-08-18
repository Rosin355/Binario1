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
//  The title shows the station's FULL name. It used to be squeezed into fixed
//  9/12-character slots, which silently CUT longer names ("MONTEGROTTO TERME" →
//  "MONTEGROT / TERME", no ellipsis). Sizing is now `StationTitleLayout`: wrap onto
//  more lines at full size first, then one shared scale down to 60%, and only past
//  that could a glyph be lost. Base sizes follow Dynamic Type (`@ScaledMetric`), and
//  each glyph keeps a `minimumScaleFactor` as the accessibility-size safety net.
//

import SwiftUI

struct DotMatrixStationTitleView: View {
    let stationName: String
    /// Bumped by the host (e.g. on Partenze tab entry) to replay the reveal.
    var animationToken: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Base sizes follow Dynamic Type; `StationTitleLayout` then wraps/scales to fit.
    @ScaledMetric(relativeTo: .largeTitle) private var primaryBase: CGFloat = 34
    @ScaledMetric(relativeTo: .title2) private var secondaryBase: CGFloat = 22
    @State private var revealed = 0
    /// Set once the reveal has finished. Kept separate from `revealed` so a later
    /// relayout (rotation, Dynamic Type) that changes the glyph count can never leave
    /// a trailing glyph dark.
    @State private var isRevealComplete = false
    /// Width the header actually gives the title. 0 until the first geometry pass.
    @State private var availableWidth: CGFloat = 0

    private var layout: StationTitleLayout.Layout {
        StationTitleLayout.layout(fullName: stationName, available: availableWidth,
                                  primaryBase: primaryBase, secondaryBase: secondaryBase)
    }

    /// Restart the reveal when the tab-entry token OR the station changes — NOT when
    /// the layout rescales, otherwise every geometry pass would replay the animation.
    private var revealKey: String { "\(animationToken)|\(stationName)" }

    var body: some View {
        let l = layout
        VStack(alignment: .leading, spacing: -2) {
            line(l.primary, globalOffset: 0, fontSize: primaryBase * l.scale,
                 color: BoardColors.ledPrimary, glow: 0.55)
            ForEach(Array(l.secondary.enumerated()), id: \.offset) { idx, text in
                line(text, globalOffset: l.primary.count + l.secondary.prefix(idx).reduce(0) { $0 + $1.count },
                     fontSize: secondaryBase * l.scale, color: BoardColors.ledSecondary, glow: 0.40)
            }
        }
        // Claim the header's remaining width so the measurement below is the width
        // AVAILABLE to the title, not the width its own content happens to want.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .accessibilityElement()
        .accessibilityLabel(Text(stationName))
        .task(id: revealKey) { await runReveal() }
    }

    @MainActor
    private func runReveal() async {
        let total = layout.totalGlyphs
        guard total > 0 else { revealed = 0; isRevealComplete = true; return }
        if reduceMotion { isRevealComplete = true; return }   // no motion → full title at once
        isRevealComplete = false
        revealed = 0
        for i in 1...total {
            try? await Task.sleep(for: .milliseconds(70))
            if Task.isCancelled { isRevealComplete = true; return }   // never leave it partial
            withAnimation(.snappy(duration: 0.22)) { revealed = i }
        }
        isRevealComplete = true                                       // guaranteed final state
    }

    @ViewBuilder
    private func line(_ text: String, globalOffset: Int,
                      fontSize: CGFloat, color: Color, glow: Double) -> some View {
        HStack(spacing: StationTitleLayout.glyphSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, ch in
                LEDGlyph(char: ch, fontSize: fontSize, color: color, glow: glow,
                         on: isRevealComplete || globalOffset + idx < revealed)
            }
        }
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
            .lineLimit(1)
            // Last resort at accessibility text sizes, where the scaled base can still
            // exceed the header: glyphs shrink rather than overflow or get cut.
            .minimumScaleFactor(StationTitleLayout.minScale)
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

/// The names that used to be cut: the longest first word and the longest qualifiers
/// in the bundled catalog.
#Preview("Nomi lunghi") {
    VStack(alignment: .leading, spacing: 18) {
        ForEach(["Terme Euganee-Abano-Montegrotto", "Reggio Emilia AV Mediopadana",
                 "Firenze Santa Maria Novella", "Milano Porta Garibaldi",
                 "Genova Piazza Principe"], id: \.self) { name in
            DotMatrixStationTitleView(stationName: name)
        }
    }
    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
    .background(BoardColors.background)
}
