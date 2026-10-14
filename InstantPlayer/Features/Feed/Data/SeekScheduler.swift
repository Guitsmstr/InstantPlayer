//
//  SeekScheduler.swift
//  InstantPlayer
//
//  Feed Data — the pure latest-wins seek-dispatch state machine (E3-S1,
//  design §2 — S6, S7, and the §8(5) storm bound).
//

import Foundation

/// The seek-dispatch state machine (design §2), owned by the `@MainActor`
/// `AVMediaPlayback` conformance — one consumer, never surfaced above the
/// seam (the seam-placement rule, architecture §4). Pure: no AVFoundation,
/// no threads, no timers — it only decides *when and what* to dispatch,
/// delegating the actual seek to the injected `dispatch` closure (the
/// conformance supplies the `AVPlayer` call; unit tests supply a recording
/// spy — design §10.2, so the dispatch decisions are testable without
/// hardware).
///
/// The bound (design §2, §8(5)): at most **one** seek in flight; while one
/// is in flight, newer preview targets *replace* the pending one (never
/// queued — the entire pending state is one target, so a fast drag cannot
/// build a seek storm); when the in-flight seek completes, exactly one
/// seek to the newest pending target is issued. `.exact` supersedes
/// pending and dispatches immediately (AVPlayer's self-superseding
/// semantics — design §0.1). Pending state is dropped on `stop()` (the
/// conformance calls `reset()`).
///
/// Completion discipline: the conformance forwards only `finished == true`
/// seek callbacks (a superseded seek's `finished == false` callback is
/// ignored — design §0.1), so the in-flight slot always refers to the seek
/// `AVPlayer` is currently serving.
@MainActor
final class SeekScheduler {
    /// What issuing a seek means. The conformance closes over its
    /// `AVPlayer`; tests record calls. Called synchronously, in the
    /// caller's main-actor turn (design §2's synchronous dispatch).
    typealias Dispatch = (_ seconds: TimeInterval, _ tolerance: MediaSeekTolerance) -> Void

    private let dispatch: Dispatch

    /// The in-flight slot: `true` from a dispatch until the matching
    /// finished completion arrives. Never two at once (§8(5)'s bound).
    private var isInFlightState = false

    /// The one pending preview target — the newest replaces any earlier
    /// one (latest wins, design §2).
    private var pendingTarget: TimeInterval?

    init(dispatch: @escaping Dispatch) {
        self.dispatch = dispatch
    }

    /// Testable introspection (design §10.2's unit rows): the machine's
    /// view of the world — the ≤ 1-in-flight bound and the single pending
    /// target, asserted directly by `SeekSchedulerTests`.
    var isInFlight: Bool {
        isInFlightState
    }

    var pending: TimeInterval? {
        pendingTarget
    }

    /// Issues a seek (design §2). A `.preview` dispatches at once when
    /// idle and otherwise *replaces* the pending target — never queued; an
    /// `.exact` supersedes any pending target and dispatches immediately.
    /// Synchronous: the dispatch happens in this main-actor turn.
    func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance) {
        switch tolerance {
        case .preview:
            guard isInFlightState else {
                isInFlightState = true
                dispatch(seconds, .preview)
                return
            }
            pendingTarget = seconds

        case .exact:
            pendingTarget = nil
            isInFlightState = true
            dispatch(seconds, .exact)
        }
    }

    /// The in-flight seek finished (the conformance forwards only
    /// `finished == true` completions). Exactly one dispatch to the newest
    /// pending target when one is held (design §2); otherwise the machine
    /// returns to idle. A stray completion with nothing in flight is
    /// ignored.
    func seekFinished() {
        guard isInFlightState else { return }
        if let target = pendingTarget {
            pendingTarget = nil
            dispatch(target, .preview)
        } else {
            isInFlightState = false
        }
    }

    /// Drops all seek state — the `stop()` hook (design §8(5)): nothing
    /// pending survives a torn-down session, and no late dispatch can
    /// follow.
    func reset() {
        pendingTarget = nil
        isInFlightState = false
    }
}
