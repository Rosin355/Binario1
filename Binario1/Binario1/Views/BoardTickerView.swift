//
//  BoardTickerView.swift
//  Binario1
//
//  Footer panel: megaphone icon · scrolling LED announcement · clock + time.
//  Scrolling advances the text content on a periodic timeline (no transform
//  animation / GeometryReader / clipping, which suppress rendering on iOS 26).
//

import SwiftUI

struct BoardTickerView: View {
    var messageKey: LocalizedStringKey = "ticker.message"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let windowSize = 34
    private let charsPerSecond = 6.0

    private var rawMessage: String { String(localized: "ticker.message") }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 12))
                .foregroundStyle(BoardColors.ticker)
                .ledGlow(BoardColors.ticker, radius: 3, opacity: 0.4)

            announcement
                .frame(maxWidth: .infinity, alignment: .leading)

            clock
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(BoardColors.panelStrong)
        .overlay(alignment: .top) {
            Rectangle().fill(BoardColors.border.opacity(0.6)).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(messageKey))
    }

    @ViewBuilder
    private var announcement: some View {
        if reduceMotion {
            styled(Text(rawMessage)).lineLimit(1).truncationMode(.tail)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / charsPerSecond)) { context in
                styled(Text(window(at: context.date))).lineLimit(1)
            }
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text(BoardFormatters.clock(context.date))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(BoardColors.ticker)
            .ledGlow(BoardColors.ticker, radius: 3, opacity: 0.4)
        }
    }

    private func window(at date: Date) -> String {
        let loop = rawMessage + rawMessage
        let chars = Array(loop)
        guard !chars.isEmpty else { return "" }
        let period = max(rawMessage.count, 1)
        let start = Int(date.timeIntervalSinceReferenceDate * charsPerSecond) % period
        var out = String()
        out.reserveCapacity(windowSize)
        for i in 0..<windowSize { out.append(chars[(start + i) % chars.count]) }
        return out
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(BoardColors.ticker)
            .ledGlow(BoardColors.ticker, radius: 3, opacity: 0.4)
    }
}

#Preview {
    VStack { Spacer(); BoardTickerView() }
        .background(BoardColors.background)
}
