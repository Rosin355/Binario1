//
//  FollowableRowModifier.swift
//  Binario1
//
//  Makes a board row tappable ("segui questo treno") only when it can honestly be
//  followed, and attaches the confirmation dialog DIRECTLY to that row.
//
//  LA1 device finding (iPhone reale, iOS 26): the dialog used to be attached to the
//  container at the top of `StationBoardView`, so its popover anchor was the whole
//  screen, not the row — tapping REG 17107 (Rovigo) opened the dialog pointing at a
//  different row (20:09 Bologna). A `confirmationDialog` modifier anchors to whatever
//  view it is attached to, so it must live on the row itself.
//
//  Two sections (Next Departures, full list) can show the SAME train at once when
//  the featured spotlight is personalized (`listRows == sortedRows`): tapping one
//  must not also arm the other's dialog. `FollowCandidate.anchorID` disambiguates by
//  row INSTANCE (section + row id), not just by train identity, so exactly the row
//  that was tapped presents.
//

import SwiftUI

/// The one row currently showing (or about to show) the follow dialog, identified by
/// instance so two on-screen copies of the same train never both arm.
struct FollowCandidate: Equatable {
    let anchorID: String
    let target: FollowedTrainTarget
}

extension View {
    /// `target` nil → the row stays exactly as it was (not tappable, no traits, no
    /// dialog). `anchorID` must be unique per row INSTANCE (callers prefix it by
    /// section, e.g. "featured-\(row.id)" vs "list-\(row.id)").
    @ViewBuilder
    func followableRow(anchorID: String,
                       target: FollowedTrainTarget?,
                       candidate: Binding<FollowCandidate?>,
                       tracker: FollowedTrainTracker?,
                       onFollowError: @escaping () -> Void) -> some View {
        if let target {
            let isPresented = Binding<Bool>(
                get: { candidate.wrappedValue?.anchorID == anchorID },
                set: { presented in if !presented { candidate.wrappedValue = nil } }
            )
            // An explicitly-typed String (not a literal at the call site) forces the
            // StringProtocol overload of `confirmationDialog`, not the LocalizedStringKey
            // one — the train label is DATA (a destination name), never a lookup key.
            // LA1 device finding: the interpolated literal was picked up by String
            // Catalog extraction as a "%@ %@ · %@" format key.
            let title: String = "\(target.category) \(target.trainNumber) · \(target.destination)"
            self
                .contentShape(Rectangle())
                .onTapGesture { candidate.wrappedValue = FollowCandidate(anchorID: anchorID, target: target) }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text("follow.action.follow")) {
                    candidate.wrappedValue = FollowCandidate(anchorID: anchorID, target: target)
                }
                .confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
                    if tracker?.isFollowing(target) == true {
                        Button("follow.action.stop", role: .destructive) {
                            Task { await tracker?.stopFollowing() }
                        }
                    } else {
                        Button("follow.action.follow") {
                            Task {
                                await tracker?.follow(target)
                                if tracker?.startErrorKey != nil { onFollowError() }
                            }
                        }
                    }
                } message: {
                    Text("follow.dialog.message")
                }
        } else {
            self
        }
    }
}

private extension FollowedTrainTarget {
    var category: String { attributes.category }
    var trainNumber: String { attributes.trainNumber }
    var destination: String { attributes.destination }
}
