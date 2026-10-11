//
//  FeedState.swift
//  InstantPlayer
//
//  Feed Presentation state value (E2-S1, design §4 — S5–S7).
//

/// The feed's presentation state machine (design §4). `FeedViewModel` is
/// the only holder (D8).
nonisolated enum FeedState {
    /// Nothing open — the drop-target welcome surface (S5).
    case welcome

    /// One open folder with its prepared snapshot (S1–S4, S13, S14).
    /// E2-S2 replaces this story's interim placeholder with the feed and
    /// starts at `collection.startIndex`.
    case folderOpen(MediaCollection)
}
