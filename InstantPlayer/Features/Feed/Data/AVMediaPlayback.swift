//
//  AVMediaPlayback.swift
//  InstantPlayer
//
//  Feed Data — one live playback session (E2-S3, design §2, §4, §5 —
//  S5–S11, S14; E3-S1, design §2, §3 — the seek mechanism and the
//  periodic clock bridge, S1–S2, S5–S7, S17).
//

import AppKit
import AVFoundation
import QuartzCore

/// One started playback session (design §2): one `AVPlayer` + its
/// `AVPlayerItem`, end/failure/first-frame observation marshaled to the
/// main actor at this boundary (design §1.2), the loop-supporting
/// `restart()`, and the layer-hosting display view (design §4).
///
/// Lifecycle (design §3): observation dies with the session — `stop()`
/// cancels every bridge, removes the KVO observations, finishes the event
/// stream (brace 1), and detaches the item, so late events can neither
/// paint nor sound (the view model adds the identity and generation
/// braces). No mutable state is shared across isolation domains (D8's
/// trigger unmet): every AVFoundation callback hops to the main actor
/// before touching session state.
///
/// Security posture (design §9): playback APIs only — no export/reader/
/// writer, nothing written anywhere, no persistence, no logging (D20).
/// Players, decoders, and observers never outlive the session (skill §3).
@MainActor
final class AVMediaPlayback: MediaPlayback {
    /// The session's player and item. Internal on purpose: the design
    /// §10.2 seam tests assert the unmuted start (S3) through `@testable`
    /// internals. Never touched outside this Data conformance.
    let player: AVPlayer
    let playerItem: AVPlayerItem

    /// The session-owned `AVPlayerLayer` — created here, hosted by the
    /// view `makeDisplayView()` vends (design §4). `resizeAspect`
    /// aspect-fits and letterboxes inside the viewport-sized cell at any
    /// size; resize and native fullscreen need no geometry code (design
    /// §0.5) — E2-S2's visual contract carries over unchanged.
    private let playerLayer: AVPlayerLayer

    /// The session's event stream (design §2) — finished by `stop()`
    /// (design §3 brace 1).
    let events: AsyncStream<MediaPlaybackEvent>
    private let continuation: AsyncStream<MediaPlaybackEvent>.Continuation

    /// Elapsed ticks (design §3): separate from `events` — the rare
    /// correctness events keep their ordered, never-dropped semantics —
    /// created with `.bufferingNewest(1)` (a stalled main actor drops
    /// stale ticks instead of replaying a backlog, design §3) and fed by
    /// the 10 Hz periodic clock bridge; finished by `stop()` (brace 1
    /// parity — both streams die with the session).
    let timeUpdates: AsyncStream<TimeInterval>
    private let timeUpdatesContinuation: AsyncStream<TimeInterval>.Continuation

    /// The seek mechanism's state machine (design §2): ≤ 1 seek in
    /// flight, one latest-wins pending target, `.exact` superseding —
    /// see `SeekScheduler`. Conformance-internal; the injected dispatch
    /// closure is the only way seeks reach the player, so completion
    /// state never crosses the seam (D8, R4). `lazy` because the closure
    /// captures `self`, which is only available once phase-1
    /// initialization completes; every access is on the main actor.
    /// `[weak self]`: the closure is retained by the scheduler, which
    /// this session owns (skill §4 — no cycle).
    private lazy var seekScheduler = SeekScheduler { [weak self] seconds, tolerance in
        self?.issueSeek(to: seconds, tolerance: tolerance)
    }

    /// The internal dispatch counter (design §10.2's noted route): how
    /// many actual seeks this session has issued to the player — the
    /// storm bound (§8(5): a burst of N preview seeks must dispatch far
    /// fewer) is asserted through `@testable` internals, since the frozen
    /// seam contract deliberately carries no state-query members.
    private(set) var seekDispatchCount = 0

    /// The periodic clock observer's token (design §3) — removed by
    /// `stop()`.
    private var timeObserver: Any?

    /// Bridges from AVFoundation threads onto the main actor (design
    /// §1.2) — cancelled by `stop()`.
    private var bridges: [Task<Void, Never>] = []
    private var statusObservation: NSKeyValueObservation?
    private var readyForDisplayObservation: NSKeyValueObservation?

    /// Set by `stop()` — after it, no event is ever emitted and every
    /// command is a no-op: the handle dies with its session (design §2;
    /// `makeDisplayView()` after `stop()` returns nothing usable).
    private var isStopped = false

    init(player: AVPlayer, playerItem: AVPlayerItem) {
        self.player = player
        self.playerItem = playerItem
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        (events, continuation) = AsyncStream.makeStream(of: MediaPlaybackEvent.self)
        (timeUpdates, timeUpdatesContinuation) = AsyncStream.makeStream(
            of: TimeInterval.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        observeEvents()
        observeClock()
    }

    // MARK: Observation → the event stream (design §2, marshaled to main)

    /// The three observation bridges (task 2.3): end-of-media →
    /// `.reachedEnd` (S11's trigger), item `.failed` → `.failed` (S14),
    /// layer first frame → `.readyForDisplay` (the poster→player swap
    /// gate, design §4). Notifications and KVO arrive on arbitrary
    /// threads; each bridge resumes on the main actor before touching
    /// session state (design §1.2, §8(6) — O(1) marshals).
    private func observeEvents() {
        let item = playerItem
        bridges.append(Task { [weak self] in
            // Kept alive across `restart()` cycles: a looped video
            // reaching its end again re-emits (S11, design §5).
            let ends = NotificationCenter.default.notifications(
                named: Notification.Name.AVPlayerItemDidPlayToEndTime, object: item
            )
            for await _ in ends {
                self?.emit(.reachedEnd)
            }
        })

        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                self?.emit(.failed)
            }
        }

        readyForDisplayObservation = playerLayer.observe(
            \.isReadyForDisplay, options: [.new]
        ) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor [weak self] in
                self?.emit(.readyForDisplay)
            }
        }
    }

    /// The single emission point — main-actor by construction; drops
    /// events after `stop()` (brace 1 lives here too: the stream is
    /// finished, nothing more is yielded).
    private func emit(_ event: MediaPlaybackEvent) {
        guard !isStopped else { return }
        continuation.yield(event)
    }

    // MARK: Clock bridge (design §3)

    /// The periodic clock bridge (task 2.5): a 100 ms (10 Hz) periodic
    /// observer on AVFoundation's queue (`queue: nil`) — a paused session
    /// produces no ticks, so there is no timer to gate (design §0.2). Each
    /// callback marshals to the main actor at this boundary (D25's brace
    /// pattern, design §1.2) before touching session state; the tick
    /// stream's `.bufferingNewest(1)` buffering means a stalled main actor
    /// drops stale ticks instead of replaying a backlog (design §3).
    private func observeClock() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: nil,
            using: { [weak self] time in
                Task { @MainActor [weak self] in
                    self?.emitTick(time)
                }
            }
        )
    }

    /// The single tick emission point — main-actor by construction; drops
    /// ticks after `stop()` (brace 1 lives here too: the stream is
    /// finished, nothing more is yielded) and non-numeric player times.
    private func emitTick(_ time: CMTime) {
        guard !isStopped, time.isNumeric else { return }
        timeUpdatesContinuation.yield(time.seconds)
    }

    // MARK: MediaPlayback (frozen seam contract, design §2)

    /// The media duration in seconds (design §3): the synchronous
    /// `AVPlayerItem.duration` value — known once the awaited asset load of
    /// `startPlayback` completed (design §0.2). A non-finite (invalid)
    /// duration answers 0 so the view model's `duration <= 0` guard
    /// rejects seek input (design §5's defensive row) instead of a `NaN`
    /// slipping past comparisons into the seek path.
    var duration: TimeInterval {
        let seconds = playerItem.duration.seconds
        return seconds.isFinite ? seconds : 0
    }

    /// Issues a seek (design §2): synchronous dispatch in this main-actor
    /// turn — the scheduler decides and `issueSeek` reaches the player
    /// before returning. `.preview` rides the scheduler (tolerant,
    /// latest-wins coalesced); `.exact` supersedes and dispatches
    /// immediately. Never changes rate (S10).
    func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance) {
        guard !isStopped else { return }
        seekScheduler.seek(to: seconds, tolerance: tolerance)
    }

    func pause() {
        guard !isStopped else { return }
        // Synchronous bite (design §8(2)): rate 0 before this returns.
        player.pause()
    }

    func resume() {
        guard !isStopped else { return }
        // Resumes from the current position. A session parked exactly at
        // its end (loop support: `actionAtItemEnd = .none`) plays zero
        // frames, emits `.reachedEnd`, and loops per S11 — no special
        // case (design §5).
        player.play()
    }

    func restart() {
        guard !isStopped else { return }
        // Seek-to-zero-and-play (S11's mechanism, design §5): an honest
        // restart of the same session — not a gapless cycle; the loop
        // *policy* lives in the view model.
        player.seek(to: .zero)
        player.play()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        // Synchronous bite (S9, design §8(2)): silence now, in this
        // main-actor turn — no audio past the page turn.
        player.pause()
        // Item detached — decode buffers release with it (design §2).
        player.replaceCurrentItem(with: nil)
        // The periodic clock observer dies with the session (design §3):
        // removed before the tick stream finishes, so no tick is emitted
        // into a finished stream.
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        // Seek state dies with the session (design §8(5)): nothing pending
        // survives, no late dispatch can follow.
        seekScheduler.reset()
        // Observers and bridges die with the session (design §3 brace 1).
        for bridge in bridges {
            bridge.cancel()
        }
        bridges = []
        statusObservation?.invalidate()
        statusObservation = nil
        readyForDisplayObservation?.invalidate()
        readyForDisplayObservation = nil
        // The display view is released: the session drops the layer —
        // detached from any host and showing nothing.
        playerLayer.removeFromSuperlayer()
        playerLayer.player = nil
        // The stream finishes on stop() — belt (design §3 brace 1); the
        // view model's identity guard is the braces' second line. The tick
        // stream finishes with it (design §3: both streams die with the
        // session).
        continuation.finish()
        timeUpdatesContinuation.finish()
    }

    func makeDisplayView() -> AnyObject {
        // The display-ready platform view (design §4): built and
        // configured here in Data; Presentation wraps it into the
        // hierarchy — a wrap, not processing (design §1.1). The wrap
        // vends it once per session; the handle is immutable per session.
        PlayerHostView(playerLayer: playerLayer)
    }

    // MARK: Seek mechanism (design §2 — conformance-internal, D8/R4)

    /// The one place a seek reaches the player (the scheduler's dispatch
    /// closure — task 2.3). The defensive re-bound (the caller clamps to
    /// `[0, duration]`; the conformance bounds again — S13), the tolerance
    /// mapping (`.preview` → `.positiveInfinity` both sides — the fastest
    /// convenient serve, approximate landing, S6; `.exact` → `.zero` both
    /// sides — the frame whose presentation interval contains the
    /// requested time, S7), and the completion discipline: only
    /// `finished == true` callbacks complete the scheduler's in-flight
    /// slot (a superseded seek reports `finished == false` — design §0.1).
    /// Completions arrive on arbitrary threads and hop to the main actor
    /// before touching session state (design §1.2); no completion event or
    /// callback crosses the seam (D8, R4); the rate is never touched (S10).
    private func issueSeek(to seconds: TimeInterval, tolerance: MediaSeekTolerance) {
        guard !isStopped else { return }
        let target = min(max(seconds, 0), duration)
        let time = CMTime(seconds: target, preferredTimescale: 600)
        seekDispatchCount += 1
        let onFinished: @Sendable (Bool) -> Void = { [weak self] finished in
            guard finished else { return }
            Task { @MainActor [weak self] in
                self?.seekScheduler.seekFinished()
            }
        }
        switch tolerance {
        case .preview:
            player.seek(
                to: time,
                toleranceBefore: .positiveInfinity,
                toleranceAfter: .positiveInfinity,
                completionHandler: onFinished
            )
        case .exact:
            player.seek(
                to: time,
                toleranceBefore: .zero,
                toleranceAfter: .zero,
                completionHandler: onFinished
            )
        }
    }
}

/// The layer-hosting host view (design §4, §0.5): keeps the session's
/// `AVPlayerLayer` sized to its bounds — AppKit-side geometry only, no
/// media operations here (they all live in this Data conformance; the
/// AVKit work is the layer, configured at session creation).
private final class PlayerHostView: NSView {
    private let playerLayer: AVPlayerLayer

    init(playerLayer: AVPlayerLayer) {
        self.playerLayer = playerLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        resizePlayerLayer()
    }

    override func layout() {
        super.layout()
        resizePlayerLayer()
    }

    /// Bounds tracking without implicit animation — the layer fills its
    /// host; `videoGravity = .resizeAspect` does the letterboxing.
    private func resizePlayerLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("PlayerHostView is created in code only")
    }
}
