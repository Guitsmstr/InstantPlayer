//
//  StubMediaPlayerService.swift
//  InstantPlayer
//
//  Feed Data stub for the player seam (E1-S3, design §3.6 — R2;
//  E2-S3, design §2 — stub session handles, task 1.5; E3-S1, design §2 —
//  the stub handle grows the seek members, task 1.3).
//

import AppKit

/// Skeleton conformance for the player seam. `startPlayback(for:)` answers
/// with a canned, never-failing stub handle; the real wrapper
/// (`AVMediaPlayerService`, E2-S3 design §2) ships alongside it in Feed
/// Data. Composition binds this stub until E2-S3's composition task — the
/// E2-S3 view model compiles from the seam commit on (design §1, task 1.5).
///
/// Zero I/O: no AVFoundation, nothing read from disk — every answer is a
/// fresh inert constant (house stub pattern; tests use their own scripted
/// doubles, design §10.1).
@MainActor
final class StubMediaPlayerService: MediaPlayerService {
    /// `nonisolated` on purpose: the composition root's default argument
    /// (`AppDependencies.init`) evaluates in a nonisolated context, and
    /// this stub holds no state to isolate — allocation-only (R13).
    nonisolated init() {}

    func wiringProbe() async -> String {
        "StubMediaPlayerService"
    }

    /// Canned answer (design §2 contract shape): a fresh inert stub handle
    /// for every call. Never fails — the seam's `nil` is reserved for real
    /// failure (S14, S15) and a stub has none; never emits events; never
    /// touches media.
    func startPlayback(for _: MediaItem) async -> MediaPlayback? {
        StubMediaPlayback()
    }
}

/// The stub session handle (design §2 shape): a session that does nothing
/// and emits nothing — its event stream stays silent until `stop()`
/// finishes it (the seam's finish-on-stop contract, design §3 brace 1).
/// E3-S1 (task 1.3) grows it honestly along the seam: a canned non-zero
/// `duration`, a `timeUpdates` stream that also finishes on `stop()`, and
/// seeks that are recorded and reflected into the position feed (the
/// `timeUpdates` ticks consumers map into displayed position) — still
/// zero I/O, no AVFoundation. Inert on purpose: with this stub bound, no
/// display state ever reaches `.player`, so the feed keeps showing posters.
@MainActor
private final class StubMediaPlayback: MediaPlayback {
    /// Canned non-zero duration (task 1.3): large enough for wiring
    /// consumers to map fractions, never derived from media (zero I/O).
    let duration: TimeInterval = 90

    let events: AsyncStream<MediaPlaybackEvent>
    private let continuation: AsyncStream<MediaPlaybackEvent>.Continuation

    /// Elapsed ticks (design §3): silent until a seek is reflected into
    /// it; finished by `stop()` like `events` (design §3 brace 1).
    let timeUpdates: AsyncStream<TimeInterval>
    private let timeUpdatesContinuation: AsyncStream<TimeInterval>.Continuation

    /// Recorded seeks (task 1.3): every call, in call order. Recording is
    /// the stub's whole seek behavior — no I/O, no player state.
    private(set) var seeks: [(seconds: TimeInterval, tolerance: MediaSeekTolerance)] = []

    init() {
        (events, continuation) = AsyncStream.makeStream(of: MediaPlaybackEvent.self)
        (timeUpdates, timeUpdatesContinuation) = AsyncStream.makeStream(of: TimeInterval.self)
    }

    func pause() {}

    func resume() {}

    func restart() {}

    /// Records the seek and reflects it into the position feed (task 1.3):
    /// the yielded tick is how a seek lands in whatever consumes
    /// `timeUpdates` into displayed position. No clamping here — clamping
    /// is the caller's contract (design §2, S13).
    func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance) {
        seeks.append((seconds, tolerance))
        timeUpdatesContinuation.yield(seconds)
    }

    func stop() {
        continuation.finish()
        timeUpdatesContinuation.finish()
    }

    func makeDisplayView() -> AnyObject {
        NSView()
    }
}
