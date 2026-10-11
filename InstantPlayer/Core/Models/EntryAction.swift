//
//  EntryAction.swift
//  InstantPlayer
//
//  Core entry value — the one routed user entry (E2-S1, design §3.1 + §5.4 — S1–S4).
//

import Foundation

/// The single internal entry value (design §3.1, §5.4): the URL the user
/// acted on. Finder "Open With", Dock-icon drop and window drop are delivery
/// channels for the same payload — S1–S4 branch only on what the URL is
/// (media file / folder / unsupported file), never on the channel. `RootView`
/// converts system events into entry actions and routes each one exactly
/// once (`FeedViewModel.handle(entryAction:)` → the `MediaFolderRepository`
/// seam); a multi-item gesture produces N actions in event order and the
/// last one wins (design §3.1).
///
/// Untrusted input (design §8.3): `enteredURL` is validated at the Data
/// edge — the seam accepts file URLs only.
nonisolated struct EntryAction: Sendable {
    /// The file or folder URL the user acted on.
    let enteredURL: URL
}
