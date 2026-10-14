//
//  MediaPlaybackSpeed.swift
//  InstantPlayer
//
//  Feed Domain playback-speed ladder (E3-S2, design §2 — S2, S5–S7).
//

/// The five selectable speeds (S2) — the ladder as a type: nothing
/// outside these cases exists to select, so no raw float can ever reach
/// AVFoundation (the enum *is* the input validation). Declaration order
/// is ladder order (`CaseIterable`) — stepping walks it (S5–S7).
/// Foundation-only (R10): no `AVPlayer`, no `AVAudioTimePitchAlgorithm`,
/// no `CMTime` in any Domain signature (the `MediaSeekTolerance`/`URL`/
/// `Data` value precedents). Plain value, no policy (D8 — stepping and
/// the guard matrix live in the view model, design §5).
nonisolated enum MediaPlaybackSpeed: Float, CaseIterable, Sendable {
    case quarter = 0.25
    case half = 0.5
    case normal = 1.0
    case oneAndHalf = 1.5
    case double = 2.0
}
