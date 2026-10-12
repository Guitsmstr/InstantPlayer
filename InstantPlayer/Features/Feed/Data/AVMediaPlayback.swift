//
//  AVMediaPlayback.swift
//  InstantPlayer
//
//  Feed Data — one live playback session (E2-S3, design §2, §4, §5 —
//  S5–S11, S14).
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
        observeEvents()
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

    // MARK: MediaPlayback (frozen seam contract, design §2)

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
        // view model's identity guard is the braces' second line.
        continuation.finish()
    }

    func makeDisplayView() -> AnyObject {
        // The display-ready platform view (design §4): built and
        // configured here in Data; Presentation wraps it into the
        // hierarchy — a wrap, not processing (design §1.1). The wrap
        // vends it once per session; the handle is immutable per session.
        PlayerHostView(playerLayer: playerLayer)
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
