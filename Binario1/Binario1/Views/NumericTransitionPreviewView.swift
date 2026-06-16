//
//  NumericTransitionPreviewView.swift
//  Binario1
//
//  DEBUG-ONLY harness to visually verify the numeric content transitions
//  (`.numericText`) used across Viaggi. Not part of production UI — it exists only
//  so a developer can confirm, in a preview, that times / platforms / durations /
//  delays actually roll when their values change. Tapping the button steps the
//  sample values inside a `withAnimation` so the digits transition.
//

#if DEBUG
import SwiftUI

struct NumericTransitionPreviewView: View {
    @State private var step = 0

    private let times     = ["07:18", "07:22", "07:30"]
    private let platforms = ["2", "4", "6"]
    private let durations = [37, 42, 51]
    private let delays    = [0, 12, 35]

    private var i: Int { step % 3 }
    private var status: JourneyStatus { delays[i] == 0 ? .onTime : .delayed(minutes: delays[i]) }

    var body: some View {
        ZStack {
            BoardBackgroundView()
            VStack(alignment: .leading, spacing: 20) {
                Text(verbatim: "NUMERIC TRANSITION TEST")
                    .font(BoardFont.text(13, .bold)).tracking(1)
                    .foregroundStyle(BoardColors.amber)

                row("TIME") {
                    LEDText(text: times[i], size: 34, animatesNumeric: true)
                }
                row("PLATFORM") {
                    LEDText(text: platforms[i], size: 34, color: BoardColors.platform, animatesNumeric: true)
                }
                row("DURATION") {
                    BoardNumberText(text: "\(durations[i]) min", size: 26, color: BoardColors.amberDim)
                }
                row("DELAY / STATUS") {
                    JourneyStatusBadgeView(status: status, fontSize: 15)
                }

                Button {
                    withAnimation(.snappy(duration: 0.45)) { step += 1 }
                } label: {
                    Text(verbatim: "Test numeric animation")
                        .font(BoardFont.text(14, .bold))
                        .foregroundStyle(BoardColors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BoardColors.amber))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .preferredColorScheme(.dark)
    }

    private func row<V: View>(_ label: String, @ViewBuilder _ value: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: label)
                .font(BoardFont.text(11, .semibold)).tracking(0.5)
                .foregroundStyle(BoardColors.amberDim)
                .frame(width: 130, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
    }
}

#Preview("Numeric transition") {
    NumericTransitionPreviewView()
}
#endif
