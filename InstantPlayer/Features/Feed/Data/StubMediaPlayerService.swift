//
//  StubMediaPlayerService.swift
//  InstantPlayer
//
//  Feed Data stub for the player seam (E1-S3, design §3.6 — R2;
//  E2-S3, design §2 — stub session handles, task 1.5).
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
/// Inert on purpose: with this stub bound, no display state ever reaches
/// `.player`, so the feed keeps showing posters.
@MainActor
private final class StubMediaPlayback: MediaPlayback {
    let events: AsyncStream<MediaPlaybackEvent>
    private let continuation: AsyncStream<MediaPlaybackEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(of: MediaPlaybackEvent.self)
    }

    func pause() {}

    func resume() {}

    func restart() {}

    func stop() {
        continuation.finish()
    }

    func makeDisplayView() -> AnyObject {
        NSView()
    }
}
