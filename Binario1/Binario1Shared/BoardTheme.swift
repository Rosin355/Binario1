//
//  BoardTheme.swift
//  Binario1
//
//  Visual identity tokens for the railway departure-board aesthetic:
//  matte black background, amber/orange LED typography, red-orange delays.
//  Tuned to the target mockup.
//

import SwiftUI

enum BoardColors {
    // Deeper, less-warm matte black (measured against the mockup: cut the lift and
    // halve the warm bias so the board reads as true sodium-amber on black).
    static let background  = Color(red: 0.012, green: 0.009, blue: 0.007)   // near-black
    static let panel       = Color(red: 0.055, green: 0.035, blue: 0.016)   // card / list / footer fill
    static let panelStrong = Color(red: 0.035, green: 0.022, blue: 0.010)

    static let amber       = Color(red: 1.0,  green: 0.52, blue: 0.02)      // primary (deep sodium amber)
    static let amberBright = Color(red: 1.0,  green: 0.60, blue: 0.06)      // time / destination / platform
    static let amberDim    = Color(red: 0.70, green: 0.42, blue: 0.06)      // numbers / secondary
    static let amberFaint  = Color(red: 0.38, green: 0.21, blue: 0.03)      // labels / hints
    static let platform    = Color(red: 1.0,  green: 0.60, blue: 0.06)

    static let delay       = Color(red: 1.0,  green: 0.22, blue: 0.07)      // 10+ min / cancelled (red-orange)
    static let cancelled   = Color(red: 1.0,  green: 0.22, blue: 0.07)
    static let delayMedium = Color(red: 1.0,  green: 0.40, blue: 0.03)      // 5–9 min (stronger orange)

    // On-time status (Viaggi): a railway green dot/label, used sparingly.
    static let statusGreen    = Color(red: 0.36, green: 0.86, blue: 0.40)
    static let statusGreenDim = Color(red: 0.24, green: 0.62, blue: 0.30)

    static let border      = Color(red: 0.42, green: 0.24, blue: 0.05)      // card / box borders
    static let borderDim   = Color(red: 0.24, green: 0.14, blue: 0.03)
    static let gridLine    = Color(red: 0.19, green: 0.10, blue: 0.02)      // dividers
    static let ticker      = Color(red: 1.0,  green: 0.52, blue: 0.06)
    static let stripBright = Color(red: 1.0,  green: 0.55, blue: 0.10)

    // Station-title LED: hotter than body amber, but still deep sodium-amber.
    static let ledPrimary   = Color(red: 1.0,  green: 0.64, blue: 0.0)      // BOLOGNA
    static let ledSecondary = Color(red: 0.90, green: 0.53, blue: 0.0)      // CENTRALE (dimmer)
}

/// Centralised board typography. The mockup uses SF Rounded for the big times /
/// platform numbers and SF (sans) for labels, destinations and chrome — only the
/// station name is a dot-matrix LED. (Kept in one place so the type system can be
/// swapped back to a fully-monospaced board if desired.)
enum BoardFont {
    /// Times and platform numbers — rounded, like the mockup's LED-segment digits.
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// Destinations, labels, "Binario", section headers, numbers.
    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Train category codes (ES, REG, AV…) — heavy italic. Caller adds `.italic()`.
    static func category(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy)
    }
}

extension View {
    /// Soft LED bloom around amber text. Tight by default so glyphs stay crisp.
    func ledGlow(_ color: Color = BoardColors.amber, radius: CGFloat = 2.5, opacity: Double = 0.3) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}
