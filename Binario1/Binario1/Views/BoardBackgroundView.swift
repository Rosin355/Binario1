//
//  BoardBackgroundView.swift
//  Binario1
//
//  The physical-board atmosphere: matte black, subtle dot-matrix grid,
//  scanlines, vignette and a faint top glass reflection. Decorative only —
//  hidden from accessibility and never interactive.
//

import SwiftUI

struct BoardBackgroundView: View {
    var body: some View {
        ZStack {
            BoardColors.background
            dotMatrix
            scanlines
            vignette
            glassReflection
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var dotMatrix: some View {
        Canvas { ctx, size in
            let step: CGFloat = 4
            let dot = Color(red: 0.78, green: 0.27, blue: 0).opacity(0.03)
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                             with: .color(dot))
                    x += step
                }
                y += step
            }
        }
    }

    private var scanlines: some View {
        Canvas { ctx, size in
            let line = Color.black.opacity(0.16)
            var y: CGFloat = 2
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                         with: .color(line))
                y += 3
            }
        }
    }

    private var vignette: some View {
        GeometryReader { geo in
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: .black.opacity(0.65), location: 1.0),
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.65
            )
        }
    }

    private var glassReflection: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [Color(red: 1, green: 0.44, blue: 0.09).opacity(0.03), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: geo.size.width * 0.84, height: geo.size.height * 0.22)
            .clipShape(.rect(bottomLeadingRadius: geo.size.width * 0.42,
                             bottomTrailingRadius: geo.size.width * 0.42))
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    BoardBackgroundView()
}
