//
//  AVMediaPlayerService.swift
//  InstantPlayer
//
//  Feed Data real conformance for the player seam
//  (E2-S3, design §1.2, §2, §3 — S1–S3, S9, S10, S14, S15).
//

import AVFoundation

/// The real `MediaPlayerService` (E2-S3 design §2): one live playback
/// session — the current item's (design §3) — over an `AVPlayer`/
/// `AVPlayerItem` on an `AVURLAsset`.
///
/// A `@MainActor final class`, not an actor (design §1.2): D8's trigger is
/// unmet — the session state's one consumer is the `@MainActor` view model,
/// and `pause()`/`stop()` must bite synchronously in the caller's
/// main-actor turn (S9's no-audio-past-the-page-turn, design §8(2)) — an
/// actor would add an executor hop to exactly those calls. No actor ships
/// in this story (design §13).
///
/// Security posture (design §9, R17/S12/S13): reads only, inside the
/// security-scoped session D19 already holds — **no**
/// `start/stopAccessingSecurityScopedResource` here, no session of its
/// own, no new grants (D21: this story expects a zero project-config
/// diff). Playback APIs only (`AVURLAsset`/`AVPlayerItem`/`AVPlayer`/
/// `AVPlayerLayer`) — no export/reader/writer, no re-encode path of any
/// kind; nothing is written anywhere; file content is played, never
/// executed; no logging of paths or file names (D20).
@MainActor
final class AVMediaPlayerService: MediaPlayerService {
    /// `nonisolated` on purpose (the `StubMediaPlayerService` precedent):
    /// the composition root's default argument (`AppDependencies.init`)
    /// evaluates in a nonisolated context, and this init is
    /// allocation-only — it touches no isolated state (the session starts
    /// `nil`; players exist only while a video is current, R13).
    nonisolated init() {}

    /// The one live session (design §3: no pooling, no warm players, no
    /// kept-alive positions) — superseded and torn down by every
    /// `startPlayback`, so memory stays bounded at one `AVPlayer` + one
    /// `AVPlayerItem` + AVFoundation decode buffers (design §8(3)).
    private var currentSession: AVMediaPlayback?

    func wiringProbe() async -> String {
        "AVMediaPlayerService"
    }

    func startPlayback(for item: MediaItem, at _: MediaPlaybackSpeed) async -> MediaPlayback? {
        // Supersede + tear down any previous session first — exactly one
        // live player, biting synchronously in this same main-actor turn
        // (design §3, §8(3)).
        currentSession?.stop()
        currentSession = nil

        // Modern async asset loading (design §0.1, §8(6)): the I/O stays
        // inside AVFoundation's own threads — never the main thread
        // (skill §1). A vanished file (S15) throws; mislabeled/undecodable
        // content (S14, D20's honest declared-type contract) answers
        // `false` — both surface as the unified `nil` failure answer,
        // the same precedent as `MediaPreviewService`.
        let asset = AVURLAsset(url: item.url)
        guard (try? await asset.load(.isPlayable)) == true else { return nil }

        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        // Loop support parks the item at its end (design §0.2, §5): the
        // end notification + the view model's `restart()` (seek-to-zero-
        // and-play) do the looping — the policy lives in the view model.
        player.actionAtItemEnd = .none

        let session = AVMediaPlayback(player: player, playerItem: playerItem)
        currentSession = session
        // Start now, without the player's waiting policy (design §0.1 —
        // local files wait for nothing; `automaticallyWaitsToMinimizeStall
        // ing` is network machinery). Task-1 minimal shape (this story's
        // task 1.6: compile-only growth) — the rate stays 1 until task 2
        // maps the seam's `at:` parameter onto `playImmediately(atRate:)`,
        // pins the pitch algorithm, and seeds the per-session speed.
        // Audio unmuted: `isMuted`/`volume` are never touched (S3 —
        // app-level volume is E3-S3).
        player.playImmediately(atRate: 1)
        return session
    }
}
