//
//  InfoView.swift
//  Binario1
//
//  Minimal Info tab: brand, a short tagline, the demo-data note and the official-
//  displays disclaimer. Keeps the board identity; auxiliary screen for the MVP.
//

import SwiftUI

struct InfoView: View {
    /// Dismisses the sheet when Info is presented modally (its only use after
    /// Info stopped being a primary tab). A no-op in standalone previews.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BoardBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 10) {
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

                        Spacer(minLength: 8)

                        closeButton
                    }

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

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BoardColors.amber)
                .frame(width: 32, height: 32)
                .background(
                    Circle().stroke(Color(red: 0.34, green: 0.27, blue: 0.16).opacity(0.8), lineWidth: 1.2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("action.close"))
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
