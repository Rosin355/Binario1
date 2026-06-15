//
//  InfoView.swift
//  Binario1
//
//  Minimal Info tab: brand, a short tagline, the demo-data note and the official-
//  displays disclaimer. Keeps the board identity; auxiliary screen for the MVP.
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        ZStack {
            BoardBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("trips.brand")               // BINARIO1
                            .font(BoardFont.text(11, .semibold))
                            .tracking(3)
                            .foregroundStyle(BoardColors.amberDim)
                        Text("tab.info")                  // INFO
                            .font(BoardFont.digits(34, .heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(BoardColors.amberBright)
                            .ledGlow(BoardColors.amber, radius: 4, opacity: 0.35)
                    }
                    .accessibilityElement(children: .combine)

                    Text("info.tagline")
                        .font(BoardFont.text(14))
                        .foregroundStyle(BoardColors.amberDim)
                        .fixedSize(horizontal: false, vertical: true)

                    panel {
                        Text("info.mockNote")
                            .font(BoardFont.text(13, .semibold))
                            .foregroundStyle(BoardColors.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("disclaimer.officialDisplays")
                        .font(BoardFont.text(12))
                        .foregroundStyle(BoardColors.amberFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BoardColors.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BoardColors.borderDim, lineWidth: 1)
                    )
            )
    }
}

#Preview {
    InfoView()
}
