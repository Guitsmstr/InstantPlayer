//
//  SeekLandingPerformanceTests.swift
//  InstantPlayerTests
//
//  The frame-exact landing budget through the player seam, measured
//  (E3-S1, design §8(2) — RNF-02).
//

import AppKit
import AVFoundation
@testable import InstantPlayer
import XCTest

/// The §8(2) landing budget, measured from tooling: an `.exact` seek —
/// the release/keypress/click commit path — issued immediately and landed
/// within ≤ 300 ms p95 for typical media (≤ 1080p clips) on Apple-silicon
/// reference hardware. Heavy media (long-GOP, 4K+) is functional-review
/// plus Instruments-escalation territory (design §2's honesty limits).
/// XCTest `measure` is the design's one deliberate Swift Testing exception
/// (task 4.2); the measured numbers are recorded as story evidence from
/// tooling (task 11.5).
///
/// The methods are `nonisolated` on purpose: the seam is `@MainActor`, so
/// each measured cycle runs as a main-actor task while the synchronous
/// (measure) body services the main actor through the run loop — a
/// semaphore bridge would starve the very executor the session needs (the
/// D25 test-infrastructure pattern, `MediaPlayerPerformanceTests`).
/// For the same reason, the fixture, service, session, and window are
/// released only inside main-actor tasks (the deallocating-deinit
/// SIGABRT lesson recorded there).
final class SeekLandingPerformanceTests: XCTestCase {
    /// One `.exact` seek → landed frame cycle, run synchronously for the
    /// measure block: a main-actor task issues the seek to the paused
    /// session and polls until the playhead sits within one frame
    /// duration of the target (the honest landing observable), while this
    /// body pumps the run loop. Alternating targets per pass force a real
    /// seek every time.
    @discardableResult
    private nonisolated func runOneSeekLandingCycle(
        box: SeekBox,
        target: TimeInterval
    ) -> Double? {
        let cycleBox = SeekCycleBox()
        let workTask = Task { @MainActor in
            await Self.runCycle(cycleBox: cycleBox, box: box, target: target)
        }
        let deadline = Date().addingTimeInterval(30)
        while cycleBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        workTask.cancel()
        guard cycleBox.done else {
            Self.recordEvidence("cycle aborted: never completed within 30 s")
            XCTFail("the seek landing cycle never completed within 30 s")
            return nil
        }
        if let failure = cycleBox.failure {
            Self.recordEvidence("cycle failed: \(failure)")
            XCTFail(failure)
            return nil
        }
        return cycleBox.elapsedMs
    }

    /// The seam work of one cycle, on the main actor: issue `.exact` to
    /// the paused session, poll for the landed frame.
    @MainActor
    private static func runCycle(
        cycleBox: SeekCycleBox,
        box: SeekBox,
        target: TimeInterval
    ) async {
        guard let session = box.session else {
            cycleBox.failure = "the session was already released"
            cycleBox.done = true
            return
        }
        let frameDuration = 1.0 / 30.0
        let started = Date()
        session.seek(to: target, tolerance: .exact)
        let deadline = started.addingTimeInterval(30)
        while Date() < deadline {
            let position = session.player.currentTime().seconds
            if position.isFinite, abs(position - target) <= frameDuration {
                cycleBox.elapsedMs = Date().timeIntervalSince(started) * 1000
                cycleBox.done = true
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        cycleBox.failure = "the exact seek never landed within 30 s"
        cycleBox.done = true
    }

    /// Builds the 720p fixture clip and the paused, first-frame-ready
    /// session (both on the main actor), pumped through the run loop like
    /// every other main-actor hop here. The displayed frame is the honest
    /// landing observable, so the session is hosted in a window and
    /// `.readyForDisplay` is awaited before the first measurement.
    private nonisolated func buildFixtureAndSession() -> SeekBox? {
        let box = SeekBox()
        let buildTask = Task { @MainActor in
            let fixture = MediaFixture()
            let clipURL = fixture.root.appending(path: "seek-720p.mp4")
            do {
                try await MediaFixture.writeShortMP4(
                    to: clipURL,
                    pixelWidth: 1280,
                    pixelHeight: 720,
                    frameCount: 60
                )
            } catch {
                box.failure = "the fixture write failed: \(error)"
            }
            guard FileManager.default.fileExists(atPath: clipURL.path) else {
                if box.failure == nil {
                    box.failure = "the performance fixture must build and exist on disk"
                }
                box.done = true
                return
            }
            box.fixture = fixture // the tree must outlive the test run
            let item = MediaItem(id: clipURL, url: clipURL, name: "seek-720p.mp4", kind: .video)
            let service = AVMediaPlayerService()
            box.service = service
            guard let handle = await service.startPlayback(for: item) else {
                box.failure = "startPlayback answered nil for a playable clip"
                box.done = true
                return
            }
            let session = handle as? AVMediaPlayback
            guard let session else {
                box.failure = "the session handle must be the real conformance"
                box.done = true
                return
            }
            box.session = session
            let host = PlaybackWindowHost()
            if let view = handle.makeDisplayView() as? NSView {
                host.host(view)
            }
            box.host = host
            var ready = false
            for await event in handle.events {
                if event == .readyForDisplay {
                    ready = true
                    break
                }
                if event == .failed {
                    break
                }
            }
            guard ready else {
                box.failure = "no .readyForDisplay within the setup"
                box.done = true
                return
            }
            handle.pause()
            try? await Task.sleep(for: .milliseconds(100)) // let the pause bite
            box.done = true
        }
        let deadline = Date().addingTimeInterval(120)
        while box.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        buildTask.cancel()
        if let failure = box.failure {
            XCTFail(failure)
            return nil
        }
        guard box.session != nil else {
            XCTFail("the performance session must be live and paused")
            return nil
        }
        return box
    }

    /// The §8(2) budget, measured: warm-up, a deterministic single-pass
    /// catch under the 300 ms typical budget, then the `measure` block
    /// recording the trend as tooling evidence.
    nonisolated func testSeekLandingBudgetThroughPlayerSeam() {
        guard let box = buildFixtureAndSession() else { return }
        Self.resetEvidenceFile()

        // Warm-up pass: the budget covers the warm app's commit path, not
        // the framework's cold seek pipeline.
        if let warmupMs = runOneSeekLandingCycle(box: box, target: 0.5) {
            Self.recordEvidence("warm-up: \(String(format: "%.1f", warmupMs)) ms")
        }

        // Deterministic single-pass catch: each exact landing must stay
        // under the typical budget (design §8(2)); the measure block
        // records the trend as tooling evidence. Targets alternate so
        // every pass forces a real seek.
        for (pass, target) in [0.5, 1.0, 1.5].enumerated() {
            guard let elapsedMs = runOneSeekLandingCycle(box: box, target: target) else { return }
            Self.recordEvidence("pass \(pass + 1) (target \(target)s): \(String(format: "%.1f", elapsedMs)) ms")
            XCTAssertLessThan(elapsedMs, 300, "300 ms typical landing budget (design §8(2)) violated")
        }

        // Tooling evidence: measured over iterations of the same cycle.
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        var measureTarget = 0.25
        measure(options: options) {
            let elapsedMs = runOneSeekLandingCycle(box: box, target: measureTarget) ?? -1
            Self.recordEvidence("measure iteration (target \(measureTarget)s): \(String(format: "%.1f", elapsedMs)) ms")
            measureTarget = measureTarget >= 1.5 ? 0.25 : measureTarget + 0.25
        }

        // The session, window, and service are released only on the
        // actor (the class comment explains why this cannot be left to
        // this nonisolated method's scope end).
        let endBox = SeekCycleBox()
        let endTask = Task { @MainActor in
            box.host?.close()
            box.host = nil
            box.session?.stop()
            box.session = nil
            box.service = nil
            endBox.done = true
        }
        let deadline = Date().addingTimeInterval(10)
        while endBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        endTask.cancel()
    }

    // MARK: Evidence capture (task 11.5)

    /// The scratch file the measured numbers land in — the app cache
    /// directory (resolves through the sandbox container when present),
    /// truncated at test start so every gate run records fresh. Test-only
    /// scratch: timing numbers, never committed.
    private nonisolated static var evidenceFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("e3s1-seek-landing-budget-evidence.txt")
    }

    private nonisolated static func resetEvidenceFile() {
        try? "e3-s1 frame-exact landing budget, measured from tooling\n".write(
            to: evidenceFile,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Appends one measured line to the scratch evidence file (best-effort:
    /// a failed write must not fail the measurement itself).
    private nonisolated static func recordEvidence(_ line: String) {
        let url = evidenceFile
        if let handle = FileHandle(forWritingAtPath: url.path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write((line + "\n").data(using: .utf8) ?? Data())
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// Main-thread-confined state for the run-loop-pumped main-actor tasks
/// above. `@unchecked Sendable` by discipline: every access happens on the
/// main thread — the pumping body and the main-actor tasks share it — so
/// there is no cross-thread state to protect.
private final class SeekBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var fixture: MediaFixture?
    var service: AVMediaPlayerService?
    var session: AVMediaPlayback?
    var host: PlaybackWindowHost?
}

/// Per-cycle result box (same discipline as `SeekBox`).
private final class SeekCycleBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var elapsedMs = 0.0
}
