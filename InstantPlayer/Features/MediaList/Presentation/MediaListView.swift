//
//  MediaListView.swift
//  InstantPlayer
//
//  MediaList Presentation list surface (E5-S1, design §2, §3.3 — S1, S2,
//  S10, S15, S16, S17).
//

import SwiftUI

/// The lazy list surface (design §2; §0 fact 1 — the chosen
/// `ScrollView` + `LazyVStack` alternative over `List`, §11): one row per
/// snapshot item in snapshot order (S1 — rows are `collection.items`
/// exactly, so the R34–R36 filtering parity is by construction), row
/// identity `MediaItem.ID` (stable within the snapshot; no diffing work
/// after open — rows are immutable per snapshot, S2). A dumb binder over
/// the view model: rows forward gestures into the machine, and an
/// empty-space click clears (S10 — row taps win where rows are, the
/// innermost gesture).
///
/// S17 opening position: on every presentation the `scrollPosition(id:)`
/// target is programmed to the feed's current item's row as a **direct
/// jump, no animation** (§7(1) — layout, not animation). §12(4) risk
/// flagged for the coordinator's first functional spike: if macOS 26
/// misbehaves on the programmatic jump (the D22 focus lesson), the
/// fallbacks are an escalation/ADR, never a silent swap.
///
/// Welcome interplay (S16): this view is mounted only in the folder-open
/// state (task 6's root wiring) — no instance exists in the welcome
/// state, so no list, toggle, or selection is reachable from it.
struct MediaListView: View {
    let viewModel: MediaListViewModel

    /// The two-way `scrollPosition(id:)` projection — written by the
    /// user's scrolling, programmed once per presentation (S17's direct
    /// jump).
    @State private var scrollTarget: MediaItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            // The list's minimal top bar — the toggle rides here, always
            // visible (design §5.2, S4).
            HStack {
                ViewToggleControl(viewModel: viewModel)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            if let collection = viewModel.collection {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(collection.items) { item in
                            MediaListRowView(item: item, viewModel: viewModel)
                        }
                    }
                }
                // S10 — a click with no row under the pointer clears the
                // selection; row gestures take precedence over this
                // container-level recognizer wherever a row is hit.
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearSelection()
                }
                .scrollPosition(id: $scrollTarget)
            }
        }
        .onAppear {
            // S17 — open on the user's place: the feed's current item's
            // row, re-derived on every presentation (the view mounts once
            // per presentation), direct jump — no animation (§7(1)).
            // Never a selection action: this writes a rendering input
            // only (design §3.3).
            scrollTarget = viewModel.highlightItemID
        }
    }
}
