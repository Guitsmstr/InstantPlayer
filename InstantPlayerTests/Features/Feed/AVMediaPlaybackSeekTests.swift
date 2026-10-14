//
//  AVMediaPlaybackSeekTests.swift
//  InstantPlayerTests
//
//  Seek/clock conformance rows over real fixture bytes (E3-S1, design
//  §10.2 — S1, S5–S7, §3, §8(5)).
//

import AppKit
import AVFoundation
@testable import InstantPlayer
import Testing

/// The real `AVMediaPlayback` seek/clock rows (design §10.2): every test
/// writes its own throwaway folder (`MediaFixture`, torn down on deinit)
/// with a real short multi-frame MP4 (`AVAssetWriter`), then drives the
/// frozen seam — `seek(to:tolerance:)`, `duration`, `timeUpdates` — and
/// asserts the §2 mechanism through `@testable` internals (the dispatch
/// counter; the design's noted route, since the frozen seam carries no
/// state-query members). Suites are `@MainActor`: the conformance is
/// MainActor-isolated (E2-S3 design §1.2).
@MainActor
struct AVMediaPlaybackSeekTests {
    private let fixture = MediaFixture()
    private let service = AVMediaPlayerService()
    private let windowHost = PlaybackWindowHost()

    /// One frame of the 30 fps fixtures — the frame-exact tolerance of
    /// the §2 honesty limits ("the frame whose presentation interval
    /// contains the requested time").
    private var frameDuration: TimeInterval {
        1.0 / 30.0
    }

    private func makeItem(_ url: URL) -> MediaItem {
        MediaItem(id: url, url: url, name: url.lastPathComponent, kind: .video)
    }

    /// Waits for the stream's first event satisfying `predicate`, bounded
    /// by `timeout` so a missing event fails the test instead of hanging
    /// the gate (the house pattern).
    private func nextEvent(
        of handle: any MediaPlayback,
        where predicate: @escaping (MediaPlaybackEvent) -> Bool,
        timeout seconds: Double = 10
    ) async -> MediaPlaybackEvent? {
        await withTaskGroup(of: MediaPlaybackEvent?.self) { group in
            group.addTask { @MainActor in
                for await event in handle.events where predicate(event) {
                    return event
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let winner = await group.next() ?? nil
            group.cancelAll()
            return winner
        }
    }

    /// The two-second fixture clip (60 frames at 30 fps) — long enough
    /// that mid-clip seek targets have real media on both sides. The
    /// session is hosted in a window and awaited to its first frame: the
    /// honest state under test is a displayed, ready session — the same
    /// setup the landing-budget perf case uses (E2-S3 design §0.3, §4;
    /// seeking before the item produces output does not land). Returns
    /// the seam handle and its `@testable` session.
    private func makeTwoSecondClip() async throws -> (any MediaPlayback, AVMediaPlayback) {
        let url = try await fixture.writeShortMP4(
            named: "clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 60
        )
        let handle = try #require(await service.startPlayback(for: makeItem(url), at: .normal))
        let session = try #require(handle as? AVMediaPlayback)
        if let view = handle.makeDisplayView() as? NSView {
            windowHost.host(view)
        }
        let ready = await nextEvent(of: handle, where: { $0 == .readyForDisplay })
        try #require(ready == .readyForDisplay, "the fixture session must reach its first frame")
        return (handle, session)
    }

    /// Polls until the playhead sits within `tolerance` of `target`
    /// (10 ms steps, bounded so a missing landing fails instead of
    /// hanging the gate).
    private func waitForLanding(
        _ session: AVMediaPlayback,
        near target: TimeInterval,
        within tolerance: TimeInterval,
        timeout seconds: Double = 10
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            let position = session.player.currentTime().seconds
            if position.isFinite, abs(position - target) <= tolerance {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    /// Polls until the playhead stops moving (the paused session's seek
    /// work has drained), bounded.
    private func waitForPositionToSettle(
        _ session: AVMediaPlayback,
        timeout seconds: Double = 10
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        var last = session.player.currentTime().seconds
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            let current = session.player.currentTime().seconds
            if current.isFinite, abs(current - last) < 0.0001 {
                return true
            }
            last = current
        }
        return false
    }

    /// One zero-tolerance seek's completion latency, measured directly on
    /// the session's player: the cost the coalescing waits on before it can
    /// dispatch the next preview. Zero tolerance is what both modes now
    /// issue (the converge amendment), so this is exactly a preview's cost.
    private func measureZeroToleranceSeek(
        _ session: AVMediaPlayback,
        to target: TimeInterval
    ) async -> TimeInterval {
        let time = CMTime(seconds: target, preferredTimescale: 600)
        let started = Date()
        await withCheckedContinuation { continuation in
            session.player.seek(
                to: time,
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { _ in
                continuation.resume()
            }
        }
        return Date().timeIntervalSince(started)
    }

    /// The scratch file the measured cadence lands in — the perf suite's
    /// pattern (the app caches directory, resolves through the sandbox
    /// container): test-only timing evidence, never committed.
    private static var cadenceEvidenceFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("e3s1-preview-cadence-evidence.txt")
    }

    /// Records the measured cadence line (best-effort: a failed write must
    /// not fail the measurement itself).
    private static func recordCadenceEvidence(_ line: String) {
        try? line.write(to: cadenceEvidenceFile, atomically: true, encoding: .utf8)
    }

    /// §10.2 row (S7 — the §2 frame-exact contract pinned): a paused
    /// session's `.exact` seek lands `currentTime` within one frame
    /// duration of the target and stays there.
    @Test func exactSeekLandsWithinOneFrameDuration() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        handle.pause()

        let target = 1.0 // on the conformance's 600-grid — no added rounding
        handle.seek(to: target, tolerance: .exact)
        let landed = await waitForLanding(session, near: target, within: frameDuration)

        #expect(landed, "the exact seek must land within one frame duration of the target (design §2, S7)")
        try await Task.sleep(for: .milliseconds(100))
        let position = session.player.currentTime().seconds
        #expect(
            position.isFinite && abs(position - target) <= frameDuration,
            "the paused playhead stays at the landed frame (S7)"
        )
        handle.stop()
    }

    /// §10.2 row (S6 — the converge amendment): a `.preview` seek issues
    /// synchronously and lands the **frame at the requested point** —
    /// within one frame duration, exactly like the `.exact` contract. The
    /// `.preview`/`.exact` split is dispatch policy (coalesced vs
    /// immediate), no longer landing slack: maximum tolerance snapped to
    /// the nearest sync sample, which was the functional-review defect.
    ///
    /// The sweep targets sit inside the first second — off the fixture's
    /// sync samples (its GOP is at least a second and no target sits on the
    /// frame-0 keyframe) — so a max-tolerance landing would snap well over
    /// a frame away and this assertion fails if `.positiveInfinity` is
    /// restored.
    @Test func previewSeekDispatchesOnceAndLandsWithinOneFrameDuration() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        handle.pause()

        let targets: [TimeInterval] = [0.2, 0.5, 0.8]
        for (index, target) in targets.enumerated() {
            handle.seek(to: target, tolerance: .preview)
            if index == 0 {
                #expect(
                    session.seekDispatchCount == 1,
                    "the preview dispatch is synchronous — one seek issued in the caller's turn"
                )
            }
            let landed = await waitForLanding(session, near: target, within: frameDuration)
            #expect(
                landed,
                "the preview must land the frame under the scrubber at \(target)s — within one frame duration (S6)"
            )
        }
        handle.stop()
    }

    /// §10.2 row + the functional-review cadence measurement (the converge
    /// amendment's decision input): with zero-tolerance previews, each
    /// coalesced landing costs one decode from the preceding sync sample.
    /// Measured on the 720p reference fixture — the design §8(2) typical
    /// media — by timing raw zero-tolerance seek completions on the paused
    /// session. The coalescing dispatches one landing per completion, so
    /// the drag's update rate is 1 / latency; the decision to keep
    /// `SeekScheduler` unchanged rests on these numbers (recorded in the
    /// story evidence from tooling, never memory).
    @Test func zeroTolerancePreviewCadenceIsSmoothOnTypicalMedia() async throws {
        let url = try await fixture.writeShortMP4(
            named: "preview-720p.mp4",
            pixelWidth: 1280,
            pixelHeight: 720,
            frameCount: 60
        )
        let handle = try #require(await service.startPlayback(for: makeItem(url), at: .normal))
        let session = try #require(handle as? AVMediaPlayback)
        if let view = handle.makeDisplayView() as? NSView {
            windowHost.host(view)
        }
        defer { windowHost.close() }
        let ready = await nextEvent(of: handle, where: { $0 == .readyForDisplay })
        try #require(ready == .readyForDisplay, "the fixture session must reach its first frame")
        handle.pause()

        // Warm-up: the first zero-tolerance seek pays the cold pipeline.
        let warmup = await measureZeroToleranceSeek(session, to: 0.5)

        // Ten alternating targets — every seek forces a real decode from
        // the preceding sync sample.
        var latencies: [TimeInterval] = []
        for index in 0 ..< 10 {
            let target = index.isMultiple(of: 2) ? 1.0 : 0.5
            latencies.append(await measureZeroToleranceSeek(session, to: target))
        }
        let average = latencies.reduce(0, +) / Double(latencies.count)
        let cadence = average > 0 ? 1.0 / average : 0
        let line = String(
            format: "e3-s1 zero-tolerance preview cadence (720p 60f): warm-up %.1f ms; "
                + "avg %.1f ms over %d seeks → %.0f updates/s",
            warmup * 1000, average * 1000, latencies.count, cadence
        )
        print(line)
        Self.recordCadenceEvidence(line)

        // The measured cadence must clear the steppy floor with margin: a
        // coalesced drag lands one frame per completion, so sub-50 ms
        // previews deliver ≥ ~20 updates/s — clearly fluid, no bounded
        // refresh policy needed.
        #expect(
            average < 0.05,
            "previews must stay fluid — avg latency under 50 ms (~20 updates/s): \(average * 1000) ms"
        )
        handle.stop()
    }

    /// §10.2 row (S6's storm bound + S7's authority, §8(5)): a burst of
    /// N preview seeks dispatches far fewer actual seeks — the pending
    /// state is one merged target — and the newest target is the one
    /// that lands.
    @Test func previewBurstDispatchesFarFewerSeeksAndNewestTargetLands() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        handle.pause()

        let burstCount = 10
        for index in 0 ..< burstCount {
            handle.seek(to: 0.2 + Double(index) * 0.08, tolerance: .preview)
        }
        #expect(
            session.seekDispatchCount == 1,
            "the synchronous burst issues exactly one dispatch (§8(5): never queued)"
        )

        // The in-flight seek's completion must dispatch the newest
        // pending target — exactly one more seek.
        var drained = false
        for _ in 0 ..< 1000 {
            if session.seekDispatchCount >= 2 {
                drained = true
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(drained, "the newest pending target must be dispatched after the completion (design §2)")
        _ = await waitForPositionToSettle(session)
        #expect(
            session.seekDispatchCount <= 3,
            "a burst of \(burstCount) previews must dispatch far fewer actual seeks (S6 storm bound)"
        )
        let position = session.player.currentTime().seconds
        #expect(
            position.isFinite && position >= 0 && position <= session.duration + 0.001,
            "the final target lands in-clip (S7's authority over the storm)"
        )
        handle.stop()
    }

    /// §10.2 row (S7): an `.exact` seek issued during a preview storm
    /// supersedes everything and lands frame-exact — the authority of the
    /// commit action.
    @Test func exactDuringPreviewStormLandsFrameExact() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        handle.pause()

        handle.seek(to: 0.2, tolerance: .preview)
        handle.seek(to: 0.4, tolerance: .preview)
        handle.seek(to: 0.6, tolerance: .preview)
        handle.seek(to: 1.0, tolerance: .exact)

        let landed = await waitForLanding(session, near: 1.0, within: frameDuration)
        #expect(landed, "the exact seek supersedes the storm and lands frame-exact (S7)")
        #expect(
            session.seekDispatchCount <= 4,
            "the storm still cannot build a queue (≤ one preview dispatch + the exact)"
        )
        handle.stop()
    }

    /// §10.2 row (design §3): `duration` is the synchronous
    /// `AVPlayerItem.duration` value — known once `startPlayback` returns.
    @Test func durationMatchesTheFixtureLength() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }

        #expect(
            abs(session.duration - 2.0) < 0.1,
            "the 60-frame 30 fps fixture's duration is known synchronously (design §3)"
        )
        handle.stop()
    }

    /// §10.2 row (design §3, §0.2): `timeUpdates` ticks at ≤ 12/s while
    /// playing and produces nothing while paused — a paused session has
    /// no timer to gate.
    @Test func timeUpdatesTickWhilePlayingAndStaySilentWhilePaused() async throws {
        let (handle, session) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        let collector = TickCollector()
        let consumer = Task { @MainActor in
            for await _ in handle.timeUpdates {
                collector.record()
            }
        }

        // One second of playing: a 10 Hz source can deliver at most
        // ~10 ticks — the ≤ 12/s ceiling holds with margin.
        try await Task.sleep(for: .milliseconds(1000))
        handle.pause()
        let playingCount = collector.count

        // Drain any one buffered tick (`.bufferingNewest(1)`) before the
        // quiet window, so the paused assertion is exact.
        try await Task.sleep(for: .milliseconds(150))
        let pausedStart = collector.count
        try await Task.sleep(for: .milliseconds(600))
        let pausedEnd = collector.count
        consumer.cancel()

        #expect(playingCount > 0, "a playing session ticks (design §3's clock bridge)")
        #expect(
            Double(playingCount) <= 12.0,
            "the tick cadence stays ≤ 12/s (10 Hz source — §3's cadence ceiling)"
        )
        #expect(pausedEnd == pausedStart, "a paused session produces no ticks (design §0.2)")
        #expect(session.seekDispatchCount == 0, "the clock must not seek (ticks are reads only, §9)")
        handle.stop()
    }

    /// §10.2 row (design §3): `stop()` finishes BOTH streams — the event
    /// stream and the tick stream die with the session.
    @Test func stopFinishesBothStreams() async throws {
        let (handle, _) = try await makeTwoSecondClip()
        defer { windowHost.close() }
        handle.pause()
        handle.stop()

        let eventsDrained = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                for await _ in handle.events {} // terminates iff the stream finished
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return false
            }
            let winner = await group.next() ?? false
            group.cancelAll()
            return winner
        }
        let ticksDrained = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                for await _ in handle.timeUpdates {} // terminates iff the stream finished
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return false
            }
            let winner = await group.next() ?? false
            group.cancelAll()
            return winner
        }

        #expect(eventsDrained, "stop() finishes the event stream (brace 1)")
        #expect(ticksDrained, "stop() finishes the tick stream too (design §3)")
    }

    /// §10.2 row (§8(5) + the E2-S3 supersede pattern): a superseded
    /// session drops pending seeks — the reset fires with the teardown,
    /// so no late dispatch ever follows, and the session dies detached
    /// and drained.
    @Test func supersededSessionDropsPendingSeeks() async throws {
        let urlA = try await fixture.writeShortMP4(
            named: "a.mp4", pixelWidth: 64, pixelHeight: 32, frameCount: 60
        )
        let urlB = try await fixture.writeShortMP4(
            named: "b.mp4", pixelWidth: 64, pixelHeight: 32, frameCount: 30
        )

        let first = try #require(await service.startPlayback(for: makeItem(urlA), at: .normal))
        let firstSession = try #require(first as? AVMediaPlayback)
        firstSession.pause()
        firstSession.seek(to: 0.5, tolerance: .preview) // dispatch 1, in flight
        firstSession.seek(to: 1.0, tolerance: .preview) // pending target
        #expect(firstSession.seekDispatchCount == 1, "one in-flight seek, one pending target")

        // A newer start supersedes and tears the previous session down
        // (§8(3) — the service's own teardown): the reset must drop the
        // pending seek with it.
        let second = try #require(await service.startPlayback(for: makeItem(urlB), at: .normal))
        let secondSession = try #require(second as? AVMediaPlayback)

        try await Task.sleep(for: .milliseconds(300))
        #expect(
            firstSession.seekDispatchCount == 1,
            "no late dispatch after the supersede — the pending state is dropped (§8(5))"
        )
        #expect(firstSession.player.currentItem == nil, "the superseded session is detached")
        #expect(firstSession.player.rate == 0, "the superseded session is silent")

        let drained = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                for await _ in firstSession.events {}
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return false
            }
            let winner = await group.next() ?? false
            group.cancelAll()
            return winner
        }
        #expect(drained, "the superseded session's stream finished (brace 1)")

        secondSession.stop()
    }
}

/// Tick counter for the clock rows (main-actor confined, like the suite).
@MainActor
private final class TickCollector {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
