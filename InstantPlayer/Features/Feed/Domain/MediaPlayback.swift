//
//  MediaPlayback.swift
//  InstantPlayer
//
//  Feed Domain playback-session handle (E2-S3, design §2 — S1–S3, S5–S11).
//

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
/// There are deliberately no seek, rate, or volume members (design §2):
/// every extra member is surface E3 must later reshape — the minimal
/// session is exactly this story's contract. Async/await only (D8, R4):
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

    /// Pauses (S5, S6) — synchronous, deterministic (design §8(2)): the
    /// rate is 0 before this returns.
    func pause()

    /// Resumes a paused session (S5, S6).
    func resume()

    /// Seeks to the beginning and plays (S11's mechanism — it lives in
    /// Data; the restart *policy* lives in the view model, design §2, §5).
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
