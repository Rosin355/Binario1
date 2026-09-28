//
//  FollowableRowModifier.swift
//  Binario1
//
//  Makes a board row tappable ("segui questo treno") only when it can honestly be
//  followed. The row keeps its own accessibility label; VoiceOver gets a named
//  action instead of a bare tap.
//

import SwiftUI

extension View {
    /// `action` nil → the row stays exactly as it was (not tappable, no traits).
    @ViewBuilder
    func followable(_ action: (() -> Void)?) -> some View {
        if let action {
            self
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("follow.action.follow"), action)
        } else {
            self
        }
    }
}
