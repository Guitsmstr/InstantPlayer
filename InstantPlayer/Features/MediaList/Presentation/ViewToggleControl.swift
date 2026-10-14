//
//  ViewToggleControl.swift
//  InstantPlayer
//
//  MediaList Presentation view-toggle button (E5-S1, design §5.2 — S4,
//  S16).
//

import SwiftUI

/// The one on-screen view toggle (S4 — the button surface over the same
/// `togglePresentation()` the ⌘L row routes to, design §5.1/§5.2). One
/// instance is rendered in the list's minimal top bar (always visible);
/// the feed-side instance joins the demand-driven overlay strip in task
/// 6's root wiring — placed without any `Features/Feed/**` edit (§5.2).
/// Both instances bind to the same toggle method. The label flips with
/// state between the two constant copies ("List" / "Feed") with the
/// corresponding system icon.
///
/// Welcome interplay (S16): nothing renders in the welcome state — the
/// control exists only where a MediaList view model does (the folder-open
/// state).
struct ViewToggleControl: View {
    let viewModel: MediaListViewModel

    var body: some View {
        Button {
            viewModel.togglePresentation()
        } label: {
            Label(
                viewModel.isListPresented ? "Feed" : "List",
                systemImage: viewModel.isListPresented ? "play.rectangle" : "list.bullet"
            )
        }
        .buttonStyle(.bordered)
    }
}
