//
//  FollowedTrainLiveActivity.swift
//  Binario1LiveActivity
//
//  A piece of the tabellone cut out into the Dynamic Island and the Lock Screen:
//  graphite black, amber LED, dot-matrix on the big time. It only DRAWS — every
//  value comes from `FollowedTrainDisplay`, built from what the app sent.
//
//  Monochrome rule: the Lock Screen may render desaturated, so nothing may rely on
//  colour alone. Delay is a FILLED chip with a "+N'" label; the platform is an
//  OUTLINED box with its "BIN." label; values not confirmed by a fresh read switch
//  to DASHED outlines and the text says so ("non aggiornato", "non più sul
//  tabellone"). Shape and words carry the meaning; colour only reinforces it.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FollowedTrainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FollowedTrainAttributes.self) { context in
            FollowedTrainLockScreenView(display: display(context))
                .activityBackgroundTint(BoardColors.background)
                .activitySystemActionForegroundColor(BoardColors.amber)
        } dynamicIsland: { context in
            let display = display(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        TrainLabelView(category: display.category, number: display.trainNumber, size: 13)
                        LEDClockText(text: display.time, size: 26)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PlatformBox(text: display.platformText, confirmed: display.valuesAreCurrent, size: 28)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(display.destination)
                        .font(BoardFont.text(16, .semibold))
                        .foregroundStyle(BoardColors.amberBright)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 10) {
                        if display.delay != nil {
                            DelayChip(display: display, size: 15)
                        }
                        StatusLinesView(display: display, size: 12)
                        Spacer(minLength: 0)
                    }
                    // Clear of the island's rounded bottom corners.
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(display.accessibilityText)
                }
            } compactLeading: {
                // Nothing but the time.
                Text(display.time)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(BoardColors.amber)
            } compactTrailing: {
                // Nothing but the platform.
                Text(display.platformText)
                    .font(BoardFont.digits(15))
                    .foregroundStyle(display.valuesAreCurrent && display.hasPlatform ? BoardColors.platform : BoardColors.amberDim)
            } minimal: {
                Text(display.platformText)
                    .font(BoardFont.digits(13))
                    .foregroundStyle(display.valuesAreCurrent && display.hasPlatform ? BoardColors.platform : BoardColors.amberDim)
            }
            .keylineTint(BoardColors.amber)
        }
    }

    private func display(_ context: ActivityViewContext<FollowedTrainAttributes>) -> FollowedTrainDisplay {
        FollowedTrainDisplay(attributes: context.attributes, state: context.state, isStale: context.isStale)
    }
}

// MARK: - Lock Screen banner: the full board row + its state

struct FollowedTrainLockScreenView: View {
    let display: FollowedTrainDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                LEDClockText(text: display.time, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    TrainLabelView(category: display.category, number: display.trainNumber, size: 14)
                    // Two lines before any ellipsis: the Lock Screen row is the one
                    // place the full destination has room.
                    Text(display.destination)
                        .font(BoardFont.text(17, .semibold))
                        .foregroundStyle(BoardColors.amberBright)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if display.delay != nil {
                    DelayChip(display: display, size: 16)
                }
                PlatformBox(text: display.platformText, confirmed: display.valuesAreCurrent, size: 30)
            }
            Rectangle()
                .fill(BoardColors.gridLine)
                .frame(height: 1)
            StatusLinesView(display: display, size: 13)
        }
        .padding(14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityText)
    }
}

// MARK: - Pieces

/// Category (heavy italic) + number, as on the board row.
private struct TrainLabelView: View {
    let category: String
    let number: String
    let size: CGFloat

    var body: some View {
        HStack(spacing: 5) {
            if !category.isEmpty {
                Text(category)
                    .font(BoardFont.category(size).italic())
                    .foregroundStyle(BoardColors.amber)
            }
            Text(number)
                .font(BoardFont.text(size - 1))
                .foregroundStyle(BoardColors.amberDim)
        }
        .lineLimit(1)
    }
}

/// State and timestamp. The timestamp is always there and never truncated: it
/// wraps rather than lose "letto HH:mm".
private struct StatusLinesView: View {
    let display: FollowedTrainDisplay
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let text = display.noLongerOnBoardText {
                Text(text)
                    .font(BoardFont.text(size, .semibold))
                    .foregroundStyle(BoardColors.amberBright)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(display.timestampText)
                .font(.system(size: size - 1, weight: display.valuesAreCurrent ? .regular : .semibold, design: .monospaced))
                .foregroundStyle(display.valuesAreCurrent ? BoardColors.amberDim : BoardColors.amberBright)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The platform: an outlined box, solid when confirmed by a fresh read, dashed and
/// dimmed when it is only the last value seen. "--" when unassigned.
private struct PlatformBox: View {
    let text: String
    let confirmed: Bool
    let size: CGFloat
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var assigned: Bool { text != FollowedTrainDisplay.noPlatform }

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "la.label.platform", table: "LiveActivity"))
                .font(BoardFont.text(8, .semibold))
                .tracking(0.5)
                .foregroundStyle(BoardColors.amberFaint)
            Text(text)
                .font(BoardFont.digits(size))
                .foregroundStyle(assigned ? BoardColors.platform : BoardColors.amberDim)
                .ledGlow(BoardColors.platform, radius: 3,
                         opacity: assigned && confirmed && !isLuminanceReduced ? 0.45 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(minWidth: size * 1.6)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(BoardColors.border,
                        style: StrokeStyle(lineWidth: confirmed ? 1.5 : 1, dash: confirmed ? [] : [3, 2]))
        )
        .opacity(confirmed ? 1 : 0.65)
    }
}

/// Delay or cancellation: a FILLED chip (inverse text), so it differs from the
/// outlined platform box by shape even in monochrome. Dashed outline when the value
/// is only last-seen. Absent when there is no delay — never a "0'".
private struct DelayChip: View {
    let display: FollowedTrainDisplay
    let size: CGFloat

    var body: some View {
        if let text = display.delayText, let state = display.delayVisualState {
            let confirmed = display.valuesAreCurrent
            VStack(spacing: 1) {
                if case .minutes = display.delay {
                    Text(String(localized: "la.label.delay", table: "LiveActivity"))
                        .font(BoardFont.text(8, .semibold))
                        .tracking(0.5)
                        .foregroundStyle(BoardColors.amberFaint)
                }
                Text(text)
                    .font(BoardFont.digits(size, .heavy))
                    .foregroundStyle(confirmed ? BoardColors.background : state.tint)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(confirmed ? state.tint : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(state.tint, style: StrokeStyle(lineWidth: 1, dash: confirmed ? [] : [3, 2]))
                    )
            }
            .fixedSize()
        }
    }
}

/// Big dot-matrix time: a plain `Text` always visible underneath, with an additive
/// grid of dark dots masked to the glyphs (same fail-safe idea as `LEDText`, drawn
/// with a `Shape` because it has to render inside a widget).
private struct LEDClockText: View {
    let text: String
    let size: CGFloat
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var font: Font { .system(size: size, weight: .heavy, design: .monospaced) }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(BoardColors.amber)
            .lineLimit(1)
            .fixedSize()
            .shadow(color: BoardColors.amber.opacity(isLuminanceReduced ? 0 : 0.45), radius: size * 0.085)
            .overlay {
                DotGrid(pitch: max(2.2, size / 11))
                    .fill(BoardColors.background)
                    .opacity(0.42)
                    .mask { Text(text).font(font).fixedSize() }
            }
    }
}

private struct DotGrid: Shape {
    let pitch: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let dot = pitch * 0.42
        var y: CGFloat = 0
        while y < rect.height {
            var x: CGFloat = 0
            while x < rect.width {
                path.addEllipse(in: CGRect(x: x, y: y, width: dot, height: dot))
                x += pitch
            }
            y += pitch
        }
        return path
    }
}

// MARK: - Previews (preview data only — never shipped as content)

#if DEBUG
private extension FollowedTrainAttributes {
    static let preview = FollowedTrainAttributes(
        stationSlug: "padova", stationName: "PADOVA", category: "REG", trainNumber: "17088",
        destination: "VENEZIA S.LUCIA", scheduledTime: "18:06", scheduledAtUnix: 0)
}

private extension FollowedTrainAttributes.ContentState {
    static let onTime = Self(tracking: .onBoard, delayMinutes: nil, isCancelled: false,
                             platform: "6", readAtUnix: Date().timeIntervalSince1970)
    static let delayed = Self(tracking: .onBoard, delayMinutes: 12, isCancelled: false,
                              platform: "6", readAtUnix: Date().timeIntervalSince1970)
    static let noPlatform = Self(tracking: .onBoard, delayMinutes: nil, isCancelled: false,
                                 platform: nil, readAtUnix: Date().timeIntervalSince1970)
    static let gone = Self(tracking: .noLongerOnBoard, delayMinutes: 5, isCancelled: false,
                           platform: "6", readAtUnix: Date().timeIntervalSince1970)
}

#Preview("Lock Screen", as: .content, using: FollowedTrainAttributes.preview) {
    FollowedTrainLiveActivity()
} contentStates: {
    FollowedTrainAttributes.ContentState.onTime
    FollowedTrainAttributes.ContentState.delayed
    FollowedTrainAttributes.ContentState.noPlatform
    FollowedTrainAttributes.ContentState.gone
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: FollowedTrainAttributes.preview) {
    FollowedTrainLiveActivity()
} contentStates: {
    FollowedTrainAttributes.ContentState.delayed
    FollowedTrainAttributes.ContentState.gone
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: FollowedTrainAttributes.preview) {
    FollowedTrainLiveActivity()
} contentStates: {
    FollowedTrainAttributes.ContentState.onTime
    FollowedTrainAttributes.ContentState.noPlatform
}
#endif
