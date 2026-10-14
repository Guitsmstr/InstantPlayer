//
//  MediaPlayback.swift
//  InstantPlayer
//
//  Feed Domain playback-session handle (E2-S3, design §2 — S1–S3, S5–S11;
//  E3-S1, design §2 — the seek seam additions, S1–S2, S5–S7, S11;
//  E3-S2, design §2 — the speed command, S10–S14).
//

import Foundation

/// The seek-tolerance modes (design §2) — the S6/S7 split as values:
/// both land the frame at the requested point (zero tolerance); the split
/// is dispatch policy — `.preview` is the drag's latest-wins coalesced
/// live preview, `.exact` is the immediate, superseding commit seek.
/// Foundation-only (R10); no third mode ever grows this type (design §12).
nonisolated enum MediaSeekTolerance: Sendable {
    /// Coalesced (S6): the drag's live preview — latest-wins dispatch
    /// (≤ 1 seek in flight; a newer target replaces the pending one,
    /// never queued). Zero-tolerance landing since the functional-review
    /// converge amendment: the displayed frame is the frame under the
    /// scrubber (a maximum-tolerance serve snapped to the nearest sync
    /// sample — the defect).
    case preview

    /// Immediate + superseding (S7): the playhead lands on the requested
    /// time — the frame whose presentation interval contains it —
    /// superseding any in-flight or pending seek. Every commit action
    /// (drag release, track click, key step).
    case exact
}

/// One started playback session — the opaque handle
/// `MediaPlayerService.startPlayback(for:)` vends (design §2). Commands,
/// events, and the display-ready platform view travel through this
/// protocol; no `AVPlayer`, `AVPlayerItem`, or `NSView` type appears in
/// any member signature (R10 — Domain stays Foundation-only; the concrete
/// session lives in Data, architecture §4 check 3). Handle identity
/// (`===`) is the exact staleness guard for late events (design §3's
/// braces — the view model pairs it with the generation counter).
///
/// `@MainActor` + `AnyObject` (design §1.2): one consumer — the
/// `@MainActor` view model — and the commands must bite synchronously:
/// `stop()`/`pause()` take effect before returning (S5, S9; design §8(2)).
///
/// There are deliberately no volume members (design §2): E3-S3 grows
/// those — the minimal session per story is the contract. E3-S1 grew
/// exactly the seek seam (design §2): `MediaSeekTolerance`, `duration`,
/// `timeUpdates`, `seek(to:tolerance:)`. E3-S2 grows exactly the speed
/// command (design §2): `setPlaybackSpeed(_:)`. Async/await only (D8, R4):
/// events are a stream, never completion handlers.
@MainActor
protocol MediaPlayback: AnyObject {
    /// The session's events (design §2): `.readyForDisplay` (the layer has
    /// its first frame — the poster→player swap gate, design §4),
    /// `.reachedEnd` (S11's trigger), `.failed` (mid-play failure, S14).
    /// Bridged from AVFoundation observations onto the main actor at the
    /// conformance boundary; the stream finishes on `stop()` (design §3
    /// brace 1 — late events never paint or sound). Which handle emitted
    /// an event is known by which stream delivered it (identity by
    /// construction).
    var events: AsyncStream<MediaPlaybackEvent> { get }

    /// The media duration in seconds (design §3): known once `startPlayback`
    /// returns — the awaited asset load has completed by then (design §0.2).
    /// A session without a usable duration answers one that fails `> 0`;
    /// the view model rejects seek input then (design §5's defensive row,
    /// S13).
    var duration: TimeInterval { get }

    /// Elapsed-position ticks (design §3) — a stream deliberately separate
    /// from `events`: the rare correctness events keep their ordered,
    /// never-dropped semantics (`MediaPlaybackEvent` is untouched, design
    /// §1) while ticks may coalesce (bounded buffering). Produced only
    /// while time advances (a paused session yields nothing — design §0.2);
    /// finishes on `stop()` like `events` (design §3 brace 1).
    var timeUpdates: AsyncStream<TimeInterval> { get }

    /// Issues a seek (design §2). Synchronous dispatch — decided and
    /// issued in this main-actor turn (design §8(6)). Both modes land the
    /// frame at the requested point (zero tolerance — the converge
    /// amendment); the split is dispatch policy: `.preview` is the drag's
    /// coalesced live preview (S6: ≤ 1 seek in flight, newer targets
    /// replace the pending one), `.exact` is every commit action's
    /// immediate seek (S7: supersedes any in-flight or pending seek).
    /// Never changes the *selected* speed (S13 — a playing video keeps
    /// its pace across a seek). Seconds are clamped by the caller to
    /// `[0, duration]` (S13) and defensively re-bounded in the
    /// conformance; completion is mechanism — no completion event or
    /// callback crosses this seam (D8, R4).
    func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance)

    /// Changes the session's playback speed (E3-S2 design §2) — a
    /// synchronous command (D25's pattern): decided and issued in this
    /// same main-actor turn.
    ///
    /// - Playing session (rate ≠ 0): the playback rate changes in this
    ///   same main-actor turn — a rate change only: no restart, no
    ///   position change, no play/pause change (S10; a speed input is
    ///   state-neutral on the play/pause axis).
    /// - Paused session (rate 0 — the frozen frame, the gesture-scoped
    ///   scrub pause, a frame parked at either end): the selection is
    ///   remembered and the next `resume()` plays at it (S11); the frozen
    ///   frame is untouched.
    /// - The session's selected speed is what `resume()` and `restart()`
    ///   use (S14) — the loop, the resume after a scrub drag or a seek,
    ///   and the toggle resume all play at the selection without
    ///   re-application.
    /// - The command never touches position (a rate write preserves it),
    ///   play/pause state, or seek behavior, and nothing crosses the seam
    ///   back — no rate read: the frozen seam carries no state-query
    ///   members (the `seekDispatchCount` precedent).
    func setPlaybackSpeed(_ speed: MediaPlaybackSpeed)

    /// Pauses (S5, S6) — synchronous, deterministic (design §8(2)): the
    /// rate is 0 before this returns.
    func pause()

    /// Resumes a paused session (S5, S6) at the session's selected speed
    /// (E3-S2 S11, S14) — the selection last commanded through
    /// `setPlaybackSpeed` (or the speed the session was started at).
    func resume()

    /// Seeks to the beginning and plays at the session's selected speed
    /// (S11's mechanism, E3-S2 S14 — it lives in Data; the restart
    /// *policy* lives in the view model, design §2, §5).
    func restart()

    /// Tears the session down now (S9; design §8(2)): rate 0, item
    /// detached, observers removed, display view released — synchronously,
    /// before this returns. The event stream finishes (design §3 brace 1);
    /// the handle dies with its session — `makeDisplayView()` after
    /// `stop()` returns nothing usable.
    func stop()

    /// The display-ready platform view (design §4): built and configured
    /// in Data (the `AVPlayerLayer` host), wrapped — never processed — by
    /// Presentation (design §1.1's architecture wording extension, the
    /// opaque display-ready-value precedent). One per session; vended by
    /// the wrap once (`makeNSView`).
    func makeDisplayView() -> AnyObject
}
