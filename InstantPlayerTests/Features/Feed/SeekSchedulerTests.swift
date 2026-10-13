//
//  SeekSchedulerTests.swift
//  InstantPlayerTests
//
//  The pure seek-dispatch state machine rows (E3-S1, design §10.1 — S6,
//  S7, and the §8(5) storm bound).
//

import Foundation
@testable import InstantPlayer
import Testing

/// What issuing a seek means — the recording spy every row asserts
/// against: calls in order, each with its target and tolerance.
@MainActor
private final class DispatchSpy {
    private(set) var calls: [SeekCall] = []

    func dispatch(_ seconds: TimeInterval, _ tolerance: MediaSeekTolerance) {
        calls.append(SeekCall(seconds: seconds, tolerance: tolerance))
    }
}

/// One recorded dispatch (the spy's unit of assertion).
private struct SeekCall: Equatable {
    let seconds: TimeInterval
    let tolerance: MediaSeekTolerance
}

/// `SeekScheduler` rows (design §10.1, the pure Feed Data block): the
/// machine is driven through its own API with a recording dispatch spy —
/// no AVFoundation, no hardware (task 4.2's framework split). The suite
/// is `@MainActor`: the scheduler is MainActor-isolated (the conformance
/// is its one consumer).
@MainActor
struct SeekSchedulerTests {
    private func makeScheduler() -> (SeekScheduler, DispatchSpy) {
        let spy = DispatchSpy()
        let scheduler = SeekScheduler { seconds, tolerance in
            spy.dispatch(seconds, tolerance)
        }
        return (scheduler, spy)
    }

    /// Row: a `.preview` when idle dispatches immediately — synchronous
    /// dispatch in the caller's turn (design §2), in flight, nothing
    /// pending.
    @Test func previewWhenIdleDispatchesImmediately() {
        let (scheduler, spy) = makeScheduler()

        scheduler.seek(to: 1, tolerance: .preview)

        #expect(
            spy.calls == [SeekCall(seconds: 1, tolerance: .preview)],
            "an idle preview dispatches at once"
        )
        #expect(scheduler.isInFlight, "the dispatched preview is in flight")
        #expect(scheduler.pending == nil, "nothing is pending yet")
    }

    /// Row: while a seek is in flight, newer preview targets *replace*
    /// the pending one — latest wins, never queued (design §2, §8(5)).
    @Test func previewWhileInFlightReplacesPendingLatestWins() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 1, tolerance: .preview)

        scheduler.seek(to: 2, tolerance: .preview)
        scheduler.seek(to: 3, tolerance: .preview)

        #expect(spy.calls.count == 1, "no new dispatch while one is in flight")
        #expect(scheduler.pending == 3, "the newest target is the one pending")
        #expect(scheduler.isInFlight, "still exactly the first seek in flight")
    }

    /// Row (§8(5)'s bound, unit-asserted): a fast drag's whole preview
    /// storm produces exactly one in-flight seek and one pending target —
    /// the pending state is one target, so a storm cannot queue seeks.
    @Test func previewStormKeepsOneInFlightAndOnePendingTarget() {
        let (scheduler, spy) = makeScheduler()

        for tick in 0 ..< 50 {
            scheduler.seek(to: Double(tick) / 10, tolerance: .preview)
        }

        #expect(spy.calls.count == 1, "the storm issues exactly one dispatch")
        #expect(scheduler.isInFlight, "at most one seek in flight (§8(5))")
        #expect(scheduler.pending == 4.9, "the entire pending state is the newest target")
    }

    /// Row: when the in-flight seek completes, exactly one seek to the
    /// newest pending target is issued (design §2).
    @Test func completionDispatchesExactlyOneSeekToNewestPendingTarget() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 1, tolerance: .preview)
        scheduler.seek(to: 2, tolerance: .preview)
        scheduler.seek(to: 3, tolerance: .preview)

        scheduler.seekFinished()

        #expect(spy.calls.count == 2, "exactly one dispatch after the completion")
        #expect(
            spy.calls.last == SeekCall(seconds: 3, tolerance: .preview),
            "the dispatch goes to the newest pending target"
        )
        #expect(scheduler.pending == nil, "the pending state is consumed")
        #expect(scheduler.isInFlight, "the dispatched seek is now in flight")
    }

    /// Row: the last completion — nothing pending — returns the machine
    /// to idle with no further dispatch.
    @Test func finalCompletionReturnsToIdle() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 1, tolerance: .preview)
        scheduler.seekFinished()

        scheduler.seekFinished()

        #expect(spy.calls.count == 1, "a completion with nothing pending dispatches nothing")
        #expect(scheduler.isInFlight == false, "the machine is idle")
        #expect(scheduler.pending == nil)
    }

    /// Row: `.exact` supersedes the pending target and dispatches
    /// immediately (S7 — AVPlayer's self-superseding semantics, design
    /// §0.1).
    @Test func exactSupersedesPendingAndDispatchesImmediately() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 1, tolerance: .preview)
        scheduler.seek(to: 2, tolerance: .preview)

        scheduler.seek(to: 5, tolerance: .exact)

        #expect(spy.calls == [
            SeekCall(seconds: 1, tolerance: .preview),
            SeekCall(seconds: 5, tolerance: .exact),
        ], "the exact seek dispatches at once, superseding the pending target")
        #expect(scheduler.pending == nil, "the pending preview is dropped")
        #expect(scheduler.isInFlight, "the exact seek is the one in flight")
    }

    /// Row: `.exact` while idle dispatches immediately — every commit
    /// action is zero-tolerance and immediate (S7).
    @Test func exactWhileIdleDispatchesImmediately() {
        let (scheduler, spy) = makeScheduler()

        scheduler.seek(to: 5, tolerance: .exact)

        #expect(spy.calls == [SeekCall(seconds: 5, tolerance: .exact)])
        #expect(scheduler.isInFlight)
        #expect(scheduler.pending == nil)
    }

    /// Row: the exact seek's completion — nothing pending — returns the
    /// machine to idle.
    @Test func exactCompletionReturnsToIdle() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 5, tolerance: .exact)

        scheduler.seekFinished()

        #expect(spy.calls.count == 1, "no further dispatch")
        #expect(scheduler.isInFlight == false)
    }

    /// Row: pending state is dropped on stop (design §8(5)) — nothing
    /// pending survives a torn-down session, and a late completion after
    /// the reset dispatches nothing.
    @Test func resetDropsPendingStateAndLateCompletionsDoNothing() {
        let (scheduler, spy) = makeScheduler()
        scheduler.seek(to: 1, tolerance: .preview)
        scheduler.seek(to: 2, tolerance: .preview)

        scheduler.reset()

        #expect(scheduler.pending == nil, "the pending target is dropped on stop")
        #expect(scheduler.isInFlight == false, "the in-flight slot is cleared on stop")

        scheduler.seekFinished()

        #expect(spy.calls.count == 1, "a late completion after the reset dispatches nothing")
    }

    /// Row: a stray completion with nothing in flight is ignored — the
    /// machine stays idle and dispatches nothing.
    @Test func strayCompletionIsIgnored() {
        let (scheduler, spy) = makeScheduler()

        scheduler.seekFinished()

        #expect(spy.calls.isEmpty, "a stray completion dispatches nothing")
        #expect(scheduler.isInFlight == false)
    }
}
