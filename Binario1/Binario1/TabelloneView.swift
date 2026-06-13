//
//  TabelloneView.swift
//  Binario1
//
//  Faithful recreation of an old Italian railway station departure board
//  (Bologna Centrale). Amber/orange LED dot-matrix aesthetic on matte black.
//

import SwiftUI

// MARK: - Palette

private enum LED {
    static let background = Color(red: 0x04 / 255, green: 0x02 / 255, blue: 0x01 / 255)

    static let title      = Color(red: 0xFF / 255, green: 0xA0 / 255, blue: 0x28 / 255)
    static let station    = Color(red: 0x3C / 255, green: 0x1B / 255, blue: 0x00 / 255)
    static let clock      = Color(red: 0xFF / 255, green: 0x8C / 255, blue: 0x18 / 255)
    static let header     = Color(red: 0x4A / 255, green: 0x1E / 255, blue: 0x00 / 255)

    static let time       = Color(red: 0xCE / 255, green: 0x6A / 255, blue: 0x18 / 255)
    static let code       = Color(red: 0xA4 / 255, green: 0x52 / 255, blue: 0x10 / 255)
    static let dest       = Color(red: 0xE2 / 255, green: 0x74 / 255, blue: 0x20 / 255)
    static let delay      = Color(red: 0xFF / 255, green: 0x38 / 255, blue: 0x0C / 255)
    static let platform   = Color(red: 0xFF / 255, green: 0xA8 / 255, blue: 0x32 / 255)
    static let ticker     = Color(red: 0xFF / 255, green: 0x74 / 255, blue: 0x00 / 255)

    static let stripBright = Color(red: 0xFF / 255, green: 0x88 / 255, blue: 0x20 / 255)
}

/// Monospaced LED-style font. VT323 is not bundled with the app, so we fall
/// back to the system monospaced face; the dot-matrix overlay supplies the
/// pixel character. If VT323 is later added to the bundle, it is used instead.
private func ledFont(_ size: CGFloat) -> Font {
    if UIFont(name: "VT323", size: size) != nil {
        return .custom("VT323", size: size)
    }
    return .system(size: size, weight: .regular, design: .monospaced)
}

// MARK: - Model

private struct TrainSpec {
    let code: String
    let dest: String
    let delay: String?     // minutes as string, e.g. "150"; nil = on time
    let platform: String
    let offset: Int        // minutes relative to "now"
}

private let trainSpecs: [TrainSpec] = [
    .init(code: "ICN  794",  dest: "TORINO P.N.",  delay: "150", platform: "1",     offset: -12),
    .init(code: "ES  9811",  dest: "LECCE",        delay: "35",  platform: "4",     offset: -5),
    .init(code: "ES  9816",  dest: "VENEZIA S.L.", delay: nil,   platform: "6",     offset: 1),
    .init(code: "REG 11465", dest: "VIGNOLA",      delay: nil,   platform: "7 OV",  offset: 4),
    .init(code: "AV  9533",  dest: "NAPOLI C.LE",  delay: nil,   platform: "11",    offset: 8),
    .init(code: "RGV 2236",  dest: "VENEZIA S.L.", delay: nil,   platform: "4",     offset: 12),
    .init(code: "AV  9985",  dest: "NAPOLI C.LE",  delay: nil,   platform: "1",     offset: 15),
    .init(code: "RGV 11536", dest: "PIACENZA",     delay: nil,   platform: "3 EST", offset: 19),
    .init(code: "REG  318",  dest: "PORTOMAGG.",   delay: nil,   platform: "3",     offset: 23),
    .init(code: "RGV 2129",  dest: "ANCONA",       delay: "30",  platform: "3",     offset: 27),
    .init(code: "REG 11422", dest: "FERRARA",      delay: nil,   platform: "6 OV",  offset: 31),
    .init(code: "REG 11639", dest: "MARZABOTTO",   delay: nil,   platform: "17",    offset: 35),
    .init(code: "AV 35528",  dest: "TORINO P.N.",  delay: nil,   platform: "4",     offset: 39),
    .init(code: "ES  9813",  dest: "LECCE",        delay: nil,   platform: "2 OV",  offset: 43),
    .init(code: "REG 11458", dest: "POGGIO RUSCO", delay: nil,   platform: "2 OV",  offset: 47),
    .init(code: "IC   588",  dest: "TRIESTE C.LE", delay: nil,   platform: "1",     offset: 52),
    .init(code: "REG 11412", dest: "PARMA",        delay: nil,   platform: "8",     offset: 55),
    .init(code: "AV  9431",  dest: "ROMA TERMINI", delay: nil,   platform: "6",     offset: 59),
    .init(code: "REG 6357",  dest: "PORRETTA T.",  delay: nil,   platform: "5 OV",  offset: 64),
    .init(code: "REG 3007",  dest: "RAVENNA",      delay: nil,   platform: "10",    offset: 70),
    .init(code: "AV 49426",  dest: "VENEZIA S.L.", delay: nil,   platform: "3",     offset: 76),
    .init(code: "REG 11442", dest: "MODENA",       delay: "10",  platform: "7",     offset: 82),
    .init(code: "FR  9705",  dest: "ROMA TERMINI", delay: nil,   platform: "9",     offset: 88),
    .init(code: "REG 5220",  dest: "REGGIO E.",    delay: nil,   platform: "5 OV",  offset: 95),
    .init(code: "AV  9437",  dest: "NAPOLI C.LE",  delay: nil,   platform: "11",    offset: 102),
]

private struct TrainRow: Identifiable {
    let id: Int
    let time: String
    let code: String
    let dest: String
    let delayStr: String?
    let platform: String
    let isDeparting: Bool
    let isPast: Bool
}

private func buildRows(now: Date) -> [TrainRow] {
    let cal = Calendar.current
    let comps = cal.dateComponents([.hour, .minute], from: now)
    let nowMins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

    return trainSpecs.enumerated().map { idx, s in
        let adj = ((nowMins + s.offset) % 1440 + 1440) % 1440
        let h = adj / 60
        let m = adj % 60
        let isDep  = s.offset >= -1 && s.offset <= 4
        let isPast = s.offset < -1
        return TrainRow(
            id: idx,
            time: String(format: "%02d:%02d", h, m),
            code: s.code,
            dest: s.dest,
            delayStr: s.delay.map { $0 + "′" },
            platform: s.platform,
            isDeparting: isDep,
            isPast: isPast
        )
    }
}

// MARK: - Column widths (matches grid-template-columns: 50px 86px 1fr 38px 62px)

private enum Col {
    static let ora: CGFloat = 50
    static let treno: CGFloat = 86
    static let rit: CGFloat = 38
    static let bin: CGFloat = 62
}

// MARK: - Main board

struct TabelloneView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LED.background.ignoresSafeArea()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    boardContent(now: context.date)
                }

                // Visual overlays (rendered above content, non-interactive)
                dotMatrix
                scanlines
                vignette
                glassReflection
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .modifier(ScreenFlicker())
        }
        .background(LED.background.ignoresSafeArea())
    }

    // MARK: Content

    @ViewBuilder
    private func boardContent(now: Date) -> some View {
        VStack(spacing: 0) {
            ledStrip
            header(now: now)
            columnHeaders
            rows(now: now)
            ticker
        }
    }

    private var ledStrip: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0x18 / 255, green: 0x08 / 255, blue: 0x00 / 255), location: 0),
                .init(color: LED.stripBright, location: 0.18),
                .init(color: LED.stripBright, location: 0.82),
                .init(color: Color(red: 0x18 / 255, green: 0x08 / 255, blue: 0x00 / 255), location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 2)
        .shadow(color: Color(red: 1, green: 0.43, blue: 0.08).opacity(0.6), radius: 4)
    }

    private func header(now: Date) -> some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PARTENZE")
                    .font(ledFont(34))
                    .tracking(3)
                    .foregroundColor(LED.title)
                    .shadow(color: Color(red: 1, green: 0.42, blue: 0).opacity(0.9), radius: 6)
                    .shadow(color: Color(red: 1, green: 0.22, blue: 0).opacity(0.38), radius: 13)
                Text("BOLOGNA CENTRALE")
                    .font(ledFont(11))
                    .tracking(2.5)
                    .foregroundColor(LED.station)
            }
            Spacer(minLength: 0)
            Text(clockString(now))
                .font(ledFont(26))
                .tracking(3)
                .foregroundColor(LED.clock)
                .shadow(color: Color(red: 1, green: 0.38, blue: 0).opacity(0.6), radius: 5)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .background(LED.background.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0xBC / 255, green: 0x40 / 255, blue: 0).opacity(0.55))
                .frame(height: 2)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            colHeader("ORA", width: Col.ora, alignment: .leading)
            colHeader("TRENO", width: Col.treno, alignment: .leading)
            colHeader("DESTINAZIONE", width: nil, alignment: .leading)
            colHeader("RIT", width: Col.rit, alignment: .trailing)
            colHeader("BIN", width: Col.bin, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.top, 3)
        .padding(.bottom, 2)
        .background(Color(red: 0x03 / 255, green: 0x01 / 255, blue: 0).opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0x4B / 255, green: 0x18 / 255, blue: 0).opacity(0.65))
                .frame(height: 1)
        }
    }

    private func colHeader(_ text: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(text)
            .font(ledFont(11))
            .tracking(1.5)
            .foregroundColor(LED.header)
            .frame(maxWidth: width == nil ? .infinity : nil,
                   alignment: alignment)
            .frame(width: width, alignment: alignment)
    }

    private func rows(now: Date) -> some View {
        let data = buildRows(now: now)
        return VStack(spacing: 0) {
            ForEach(data) { row in
                trainRowView(row)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    @ViewBuilder
    private func trainRowView(_ row: TrainRow) -> some View {
        HStack(spacing: 0) {
            Text(row.time)
                .font(ledFont(17))
                .tracking(0.4)
                .foregroundColor(LED.time)
                .shadow(color: Color(red: 0.8, green: 0.34, blue: 0).opacity(0.38), radius: 1.5)
                .frame(width: Col.ora, alignment: .leading)

            Text(row.code)
                .font(ledFont(15))
                .tracking(0.2)
                .foregroundColor(LED.code)
                .lineLimit(1)
                .frame(width: Col.treno, alignment: .leading)

            Text(row.dest)
                .font(ledFont(17))
                .tracking(0.3)
                .foregroundColor(LED.dest)
                .shadow(color: Color(red: 0.88, green: 0.38, blue: 0).opacity(0.3), radius: 2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let d = row.delayStr {
                    DelayText(text: d)
                } else {
                    Text("")
                }
            }
            .frame(width: Col.rit, alignment: .trailing)

            Text(row.platform)
                .font(ledFont(18))
                .tracking(0.5)
                .foregroundColor(LED.platform)
                .shadow(color: Color(red: 1, green: 0.57, blue: 0).opacity(0.65), radius: 4.5)
                .shadow(color: Color(red: 1, green: 0.34, blue: 0).opacity(0.28), radius: 9)
                .frame(width: Col.bin, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.leading, row.isDeparting ? 6 : 8)
        .padding(.trailing, 8)
        .background(rowBackground(row))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(row.isDeparting
                      ? Color(red: 1, green: 0.63, blue: 0.16).opacity(0.8)
                      : Color.clear)
                .frame(width: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(row.isDeparting
                      ? Color(red: 1, green: 0.47, blue: 0).opacity(0.45)
                      : Color(red: 0.2, green: 0.07, blue: 0).opacity(0.56))
                .frame(height: 1)
        }
    }

    private func rowBackground(_ row: TrainRow) -> Color {
        if row.isDeparting {
            return Color(red: 1, green: 0.39, blue: 0).opacity(0.2)
        } else if row.isPast {
            return Color.black.opacity(0.22)
        } else if row.id % 2 == 1 {
            return Color(red: 1, green: 0.23, blue: 0).opacity(0.03)
        }
        return .clear
    }

    private var ticker: some View {
        TickerView(
            text: "RITARDI FINO A 120 MINUTI O VARIAZIONI PER ACCESSI    ◆    BIGLIETTI E ABBONAMENTI ALLE BIGLIETTERIE AUTOMATICHE    ◆    TRENITALIA SPA - BOLOGNA CENTRALE    ◆    INFORMAZIONI AL PUNTO DI ASSISTENZA    ◆    "
        )
        .frame(height: 27)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0x03 / 255, green: 0x01 / 255, blue: 0).opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 0xBC / 255, green: 0x40 / 255, blue: 0).opacity(0.55))
                .frame(height: 2)
        }
    }

    private func clockString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: Overlays

    private var dotMatrix: some View {
        Canvas { ctx, size in
            let step: CGFloat = 3
            let dot = Color(red: 0.78, green: 0.27, blue: 0).opacity(0.15)
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(dot)
                    )
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var scanlines: some View {
        Canvas { ctx, size in
            let line = Color.black.opacity(0.21)
            var y: CGFloat = 2
            while y < size.height {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 2)),
                    with: .color(line)
                )
                y += 4
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var vignette: some View {
        GeometryReader { geo in
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: Color.black.opacity(0.74), location: 1.0),
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.62
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var glassReflection: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color(red: 1, green: 0.44, blue: 0.09).opacity(0.055),
                    .clear,
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: geo.size.width * 0.84, height: geo.size.height * 0.3)
            .clipShape(.rect(bottomLeadingRadius: geo.size.width * 0.42,
                             bottomTrailingRadius: geo.size.width * 0.42))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Delay text (pulsing)

private struct DelayText: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        Text(text)
            .font(ledFont(16))
            .tracking(0.5)
            .foregroundColor(LED.delay)
            .shadow(color: Color(red: 1, green: 0.16, blue: 0).opacity(0.72), radius: 3.5)
            .shadow(color: Color(red: 1, green: 0.06, blue: 0).opacity(0.32), radius: 7)
            .opacity(pulse ? 0.42 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Scrolling ticker

private struct TickerView: View {
    let text: String
    @State private var width: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                segment
                segment
            }
            .offset(x: offset)
            .onAppear { restartAnimation() }
        }
        .clipped()
    }

    private var segment: some View {
        Text(text)
            .font(ledFont(15))
            .tracking(1.8)
            .foregroundColor(LED.ticker)
            .shadow(color: Color(red: 1, green: 0.38, blue: 0).opacity(0.48), radius: 3)
            .fixedSize()
            .background(
                GeometryReader { g in
                    Color.clear.onAppear { width = g.size.width }
                }
            )
    }

    private func restartAnimation() {
        guard width > 0 else {
            // width not measured yet; retry shortly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { restartAnimation() }
            return
        }
        offset = 0
        let speed: CGFloat = 50 // points per second
        let duration = Double(width / speed)
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -width
        }
    }
}

// MARK: - Screen flicker

private struct ScreenFlicker: ViewModifier {
    @State private var flicker = false

    func body(content: Content) -> some View {
        content
            .opacity(flicker ? 0.97 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    flicker = true
                }
            }
    }
}

#Preview {
    TabelloneView()
}
