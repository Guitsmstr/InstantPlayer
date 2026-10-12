//
//  MediaPreviewService.swift
//  InstantPlayer
//
//  Feed Domain preview seam (E2-S2, design §3 — S3, S12, S13).
//

/// Preview service seam (E2-S2 design §3): Presentation reaches static
/// media previews only through this abstraction — never AVFoundation or
/// ImageIO directly. Owned by Feed's Domain because previews have one v1
/// consumer (seam placement rule, architecture §4); `MediaPlayerService`
/// stays the playback seam E2-S3 replaces — the poster is deliberately not
/// a player concern (design §4.1).
///
/// Nonisolated on purpose: this is a pure contract — isolation belongs to
/// conformances. The shipped conformance is an actor whose extraction,
/// decode, downsample, and encode work must run off the main thread (design
/// §4.2, §8(2)); the project's default-MainActor isolation must not pin the
/// seam to main (same reasoning as `MediaFolderRepository`).
///
/// Members are the frozen contract (design §3) — async/await only, no
/// completion handlers; Domain stays Foundation-only (R10).
nonisolated protocol MediaPreviewService: Sendable {
    /// The item's display-ready preview, or `nil` — the single unified
    /// failure answer: a vanished/unreadable file (S12) and undecodable/
    /// mislabeled content (S13, D20's honest declared-type contract) both
    /// surface as `nil`.
    ///
    /// Contract (design §3): idempotent per item; concurrent calls for one
    /// item coalesce into a single extraction; the call is cancellation-
    /// aware (a cancelled task never completes its extraction); results are
    /// display-sized (§5), never full-resolution.
    func preview(for item: MediaItem) async -> MediaPreview?

    /// Drops all cached previews and in-flight work (design §3). Called on
    /// replace-in-place (S9) and on returning to welcome, so derived data
    /// has exactly the open session's lifetime (design §8).
    func discardPreviews() async

    /// Wiring probe — same contract as MediaFolderRepository.wiringProbe();
    /// proves the binding in wiring tests.
    func wiringProbe() async -> String
}
