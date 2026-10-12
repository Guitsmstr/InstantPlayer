//
//  MediaPlayerService.swift
//  InstantPlayer
//
//  Feed Domain player seam (E1-S3, design §3.5 — R2, R10, R11;
//  E2-S3, design §2 — S1–S3, S9, S10, S14, S15).
//

/// Player service seam (R11): Presentation and Domain reach playback only
/// through this abstraction — never AVKit/AVPlayer directly. Owned by
/// Feed's Domain because playback has one v1 consumer (seam placement
/// rule, design §2.2). Domain stays Swift-pure (R10): no imports at all —
/// the opaque session handle and event value are Domain types.
///
/// E2-S3 (design §2) grows the seam to its real members. `@MainActor` +
/// `AnyObject` on purpose (design §1.2): the session state is mutable
/// class state whose one consumer is the `@MainActor` view model, so D8's
/// actor trigger is unmet — and `stop()`/`pause()` must bite synchronously
/// in the caller's main-actor turn (S9's no-audio-past-the-page-turn,
/// design §8(2)); an actor would add an executor hop to exactly those
/// calls. Conformances are `@MainActor` classes (design §1.2).
@MainActor
protocol MediaPlayerService: AnyObject {
    /// Starts a playback session for `item` (S1, S3): supersedes and tears
    /// down any previous session — exactly one live player (design §3,
    /// §8(3)); awaits the asset being loadable/playable (AVFoundation-
    /// internal I/O — never the main thread, design §8(6)); starts playing
    /// with audio unmuted (the conformance never touches `isMuted`/
    /// `volume` — S3; app-level volume is E3-S3).
    ///
    /// Returns the opaque session handle, or `nil` — the unified failure
    /// answer: a vanished file (S15), a mislabeled/undecodable file (S14,
    /// D20's honest declared-type contract), or an unplayable asset — the
    /// same `nil` precedent as `MediaPreviewService`.
    func startPlayback(for item: MediaItem) async -> MediaPlayback?

    /// Wiring probe — same contract as MediaFolderRepository.wiringProbe().
    func wiringProbe() async -> String
}
