//
//  MediaPlayerPerformanceTests.swift
//  InstantPlayerTests
//
//  Auto-play start budget through the player seam, measured (E2-S3,
//  design §8(1) — RNF-02).
//

import AppKit
@testable import InstantPlayer
import XCTest

/// The §8(1) auto-play start budget, measured from tooling: from the
/// settle-equivalent start call to audibly playing with the first frame
/// shown (`.readyForDisplay`) — ≤ 300 ms p95 for typical media (≤ 1080p
/// clips) on Apple-silicon reference hardware. Heavy media (4K+) is
/// functional-review plus Instruments-escalation territory (design §8(1)).
/// XCTest `measure` is the design's one deliberate Swift Testing exception
/// (tasks.md 7.2); the measured numbers are recorded as story evidence
/// from tooling (task 10.5).
///
/// The methods are `nonisolated` on purpose: the seam is `@MainActor`, so
/// each measured cycle runs as a main-actor task while the synchronous
/// (measure) body services the main actor through the run loop — the
/// E2-S2 semaphore bridge cannot be reused here, because blocking the
/// main thread with a semaphore would starve the very executor the
/// session needs.
///
/// The service therefore lives in the main-thread-confined box for the
/// test's whole lifetime: it is created inside a main-actor task and its
/// last release happens inside a final main-actor task. Releasing the
/// `@MainActor` service (or its retained `AVMediaPlayback` session) from
/// this nonisolated body would route the deinit through the executor hop,
/// which crashes in the Swift runtime's TaskLocal teardown (observed as
/// SIGABRT in `AVMediaPlayback.__deallocating_deinit`); the Swift Testing
/// seam suites never hit this, because their releases happen inside
/// MainActor context already.
final class MediaPlayerPerformanceTests: XCTestCase {
    /// One start call → `.readyForDisplay` cycle, run synchronously for
    /// the measure block: a main-actor task does the seam work (start,
    /// host the display view, wait for the first-frame event, stop) while
    /// this body pumps the run loop. Returns the elapsed milliseconds, or
    /// nil — after failing — when the cycle did not complete.
    @discardableResult
    private nonisolated func runOneStartToReadyCycle(
        box: MainThreadBox,
        item: MediaItem
    ) -> Double? {
        let cycleBox = CycleBox()
        let workTask = Task { @MainActor in
            await Self.runCycle(cycleBox: cycleBox, box: box, item: item)
        }
        let deadline = Date().addingTimeInterval(30)
        while cycleBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        workTask.cancel()
        guard cycleBox.done else {
            Self.recordEvidence("cycle aborted: never completed within 30 s")
            XCTFail("the start→readyForDisplay cycle never completed within 30 s")
            return nil
        }
        if let failure = cycleBox.failure {
            Self.recordEvidence("cycle failed: \(failure)")
            XCTFail(failure)
            return nil
        }
        return cycleBox.elapsedMs
    }

    /// The seam work of one cycle, on the main actor: start, host the
    /// display view, wait for the first-frame event, stop, record.
    @MainActor
    private static func runCycle(
        cycleBox: CycleBox,
        box: MainThreadBox,
        item: MediaItem
    ) async {
        let host = PlaybackWindowHost()
        defer { host.close() }
        guard let service = box.service else {
            cycleBox.failure = "the player service was already released"
            cycleBox.done = true
            return
        }
        let started = Date()
        guard let handle = await service.startPlayback(for: item, at: .normal) else {
            cycleBox.failure = "startPlayback answered nil for a playable clip"
            cycleBox.done = true
            return
        }
        if let view = handle.makeDisplayView() as? NSView {
            host.host(view)
        }
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
        let elapsedMs = Date().timeIntervalSince(started) * 1000
        handle.stop()
        if ready {
            cycleBox.elapsedMs = elapsedMs
        } else {
            cycleBox.failure = "no .readyForDisplay within the cycle"
        }
        cycleBox.done = true
    }

    /// Builds the generated fixture clip (a real 720p multi-frame H.264
    /// MP4 — the typical budget's ≤ 1080p case) inside the throwaway
    /// fixture tree and creates the player service, both on the main
    /// actor. Returns the box — NOT the item — because the box is what
    /// retains the fixture and the service for the test's whole lifetime
    /// (see the class comment for why the service must be released on the
    /// actor). Pumped through the run loop like every other main-actor
    /// hop here.
    private nonisolated func buildFixtures() -> MainThreadBox? {
        let box = MainThreadBox()
        let buildTask = Task { @MainActor in
            let fixture = MediaFixture()
            let clipURL = fixture.root.appending(path: "clip-720p.mp4")
            // 15 frames (0.5 s) is ample for the measured window: the
            // budget covers start → first frame, and the cycle stops the
            // session right after `.readyForDisplay`.
            do {
                try await MediaFixture.writeShortMP4(
                    to: clipURL,
                    pixelWidth: 1280,
                    pixelHeight: 720,
                    frameCount: 15
                )
            } catch {
                box.failure = "the fixture write failed: \(error)"
            }
            if FileManager.default.fileExists(atPath: clipURL.path) {
                box.item = MediaItem(id: clipURL, url: clipURL, name: "clip-720p.mp4", kind: .video)
                box.fixture = fixture // the tree must outlive the test run
                box.service = AVMediaPlayerService()
            } else if box.failure == nil {
                box.failure = "the performance fixture must build and exist on disk"
            }
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
        guard box.item != nil else {
            XCTFail("the performance fixture must build and exist on disk")
            return nil
        }
        return box
    }

    /// The §8(1) budget, measured: warm-up, a deterministic single-pass
    /// catch under the 300 ms typical budget, then the `measure` block
    /// recording the trend as tooling evidence.
    nonisolated func testAutoPlayStartBudgetThroughPlayerSeam() {
        guard let box = buildFixtures(), let item = box.item else { return }
        Self.resetEvidenceFile()

        // Warm-up pass: framework cold-start is not the start budget's
        // subject — the budget covers the warm app's become-current path.
        if let warmupMs = runOneStartToReadyCycle(box: box, item: item) {
            Self.recordEvidence("warm-up: \(String(format: "%.1f", warmupMs)) ms")
        }

        // Deterministic single-pass catch: each fresh start-to-first-frame
        // cycle must stay under the typical budget (design §8(1)); the
        // measure block below records the trend as tooling evidence.
        for pass in 1 ... 3 {
            guard let elapsedMs = runOneStartToReadyCycle(box: box, item: item) else { return }
            Self.recordEvidence("cold-pass \(pass): \(String(format: "%.1f", elapsedMs)) ms")
            XCTAssertLessThan(elapsedMs, 300, "300 ms typical start budget (design §8(1)) violated")
        }

        // Tooling evidence: measured over iterations over the generated
        // fixture — each pass is one start call to `.readyForDisplay`.
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(options: options) {
            let elapsedMs = runOneStartToReadyCycle(box: box, item: item) ?? -1
            Self.recordEvidence("measure iteration: \(String(format: "%.1f", elapsedMs)) ms")
        }

        // The service's last release happens on the actor (the class
        // comment explains why this cannot be left to this nonisolated
        // method's scope end).
        let endBox = CycleBox()
        let endTask = Task { @MainActor in
            box.service = nil
            endBox.done = true
        }
        let deadline = Date().addingTimeInterval(10)
        while endBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        endTask.cancel()
    }

    // MARK: Evidence capture (task 10.5)

    /// The scratch file the measured numbers land in — the app cache
    /// directory (resolves through the sandbox container when present),
    /// truncated at test start so every gate run records fresh. Test-only
    /// scratch: timing numbers, never committed.
    private nonisolated static var evidenceFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("e2s3-autoplay-start-budget-evidence.txt")
    }

    private nonisolated static func resetEvidenceFile() {
        try? "e2-s3 auto-play start budget, measured from tooling\n".write(
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
private final class MainThreadBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var item: MediaItem?
    var fixture: MediaFixture?
    var service: AVMediaPlayerService?
}

/// Per-cycle result box (same discipline as `MainThreadBox`).
private final class CycleBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var elapsedMs = 0.0
}
