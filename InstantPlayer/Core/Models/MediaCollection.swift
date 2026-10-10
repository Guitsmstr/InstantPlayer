//
//  MediaCollection.swift
//  InstantPlayer
//
//  Core prepared-collection value (E2-S1, design §5.4 + §6 — S1–S4, S13, S14).
//

import Foundation

/// The prepared media collection for one open folder (design §5.4): the
/// opened folder, its media in the folder's own order, the starting-item
/// index, and the capture moment.
///
/// Snapshot contract (S13, design §6): produced once per entry action and
/// never changed afterwards — no folder watching, no re-scan on read. After
/// open the collection may drift from disk until the next entry action;
/// later additions are absent, later removals surface at consumption time.
nonisolated struct MediaCollection: Sendable {
    /// The folder that was opened and scanned.
    let folderURL: URL
    /// The folder's direct-children media in the folder's own order (S14) —
    /// no sorting applied.
    let items: [MediaItem]
    /// Where the feed starts. Invariant: `0 <= startIndex < items.count` —
    /// an empty result is never a collection (the seam returns `nil` and the
    /// app stays in the welcome state, design §3.3 step 5).
    let startIndex: Int
    /// The snapshot marker (S13).
    let capturedAt: Date
}
