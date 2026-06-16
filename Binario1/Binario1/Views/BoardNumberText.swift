//
//  BoardNumberText.swift
//  Binario1
//
//  Reusable numeric-text helpers for the board's DYNAMIC numbers (clock times,
//  platforms, durations, delays). Provides:
//   • `BoardNumber.value(from:)` — a rolling key derived from a string's digits.
//   • `BoardNumberText` — a reliable, one-line numeric label with a rolling
//      `.numericText` content transition (used for compact rows where a dot
//      renderer could wrap).
//   • `.boardNumericTransition(...)` — adds the rolling transition to an existing
//      numeric Text, keeping its own font/style.
//
//  IMPORTANT: numeric transitions are for NUMBERS only — never apply to station
//  names, route names, train categories or other non-numeric labels. All variants
//  are no-ops under Reduce Motion (the final value is rendered without rolling).
//

import SwiftUI

enum BoardNumber {
    /// Monotonic-ish rolling key for `.numericText(value:)`: the digits of `text`
    /// read as a Double (e.g. "07:18" → 718, "+12 min" → 12, "--" → 0). Used only
    /// to drive the digit-roll direction; it never changes the displayed string.
    static func value(from text: String) -> Double { Double(text.filter(\.isNumber)) ?? 0 }
}

/// A reliable, board-styled numeric label with a rolling numeric content
/// transition. One line, monospaced digits — safe for compact rows.
struct BoardNumberText: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.Weight = .bold
    var design: Font.Design = .rounded
    var color: Color = BoardColors.amber
    var glow: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: design))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .ledGlow(color, radius: glow > 0 ? size * 0.12 : 0, opacity: glow)
            .contentTransition(reduceMotion ? .identity : .numericText(value: BoardNumber.value(from: text)))
    }
}

extension View {
    /// Rolling numeric content transition for an existing numeric Text, deriving
    /// the value from the digits in `text`. No-op under Reduce Motion.
    func boardNumericTransition(_ text: String) -> some View {
        modifier(BoardNumericTransition(value: BoardNumber.value(from: text)))
    }

    /// Rolling numeric content transition driven by an explicit value.
    func boardNumericTransition(value: Double) -> some View {
        modifier(BoardNumericTransition(value: value))
    }
}

private struct BoardNumericTransition: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText(value: value))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        BoardNumberText(text: "08:32", size: 18, color: BoardColors.amberBright, glow: 0.3)
        BoardNumberText(text: "37 min", size: 16, color: BoardColors.amberDim)
    }
    .padding()
    .background(BoardColors.background)
}
