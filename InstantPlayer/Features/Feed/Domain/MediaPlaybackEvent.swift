//
//  MediaPlaybackEvent.swift
//  InstantPlayer
//
//  Feed Domain playback event value (E2-S3, design §2 — S2, S4, S11, S14).
//

/// One playback-session event (design §2) — a pure value, no associated
/// state. Which handle emitted it is known by *which stream* delivered it
/// (identity by construction, design §2; the view model's handle-identity
/// brace is design §3). Foundation-only (R10).
nonisolated enum MediaPlaybackEvent: Sendable {
    /// The layer has its first frame (design §0.3, §4) — the gate that
    /// swaps the poster for the player surface. The poster is frame 0:
    /// identical pixels, no flash (design §4).
    case readyForDisplay

    /// The item reached its end (S11's trigger): the view model restarts
    /// the same session and never advances the feed (design §5).
    case reachedEnd

    /// Mid-play failure (S14): the view model stops the session and shows
    /// the sticky neutral unavailable state (design §7).
    case failed
}
