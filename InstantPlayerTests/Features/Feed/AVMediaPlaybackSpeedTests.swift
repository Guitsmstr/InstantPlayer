//
//  AVMediaPlaybackSpeedTests.swift
//  InstantPlayerTests
//
//  Playback-speed conformance rows over real fixture bytes (E3-S2,
//  design §10.2 — S10–S15; §8(1), §8(3) — the measured budgets).
//

import AppKit
import AVFoundation
@testable import InstantPlayer
import Testing
import XCTest

/// The real `AVMediaPlayback` speed rows (design §10.2): every test
/// writes its own throwaway folder (`MediaFixture`, torn down on deinit)
/// with a real short multi-frame MP4 **with an audio track**, then drives
/// the rate seam — `startPlayback(for:at:)`, `setPlaybackSpeed`,
/// `resume`/`restart` — and asserts the §2 mapping through `@testable`
/// internals (the D25 unmuted-start route, since the frozen seam carries
/// no state-query members). Suites are `@MainActor`: the conformance is
/// MainActor-isolated (E2-S3 design §1.2).
///
/// `.serialized` on purpose (the review fix for the E2-S2 preview-budget
/// gate flake): these rows are independent, but each writes an
/// audio+video fixture and hosts a real `AVPlayer` in a window — run
/// concurrently they stack seven encoders and seven players/windows on
/// the machine at once, which is exactly the load under which the
/// parallel-runner `MediaPreviewPerformanceTests` p95 decode budget
/// (another runner process, measured in the same window) grew a heavy
/// tail. One fixture encode + one session + one window at a time keeps
/// this suite's footprint at the pre-story level; every row still pins
/// the same contract.
@Suite(.serialized)
@MainActor
struct AVMediaPlaybackSpeedTests {
    private let fixture = MediaFixture()
    private let service = AVMediaPlayerService()
    private let windowHost = PlaybackWindowHost()

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

    /// The audio-track fixture clip started at `speed`: the session is
    /// hosted in a window (the honest displayed state — the house pattern)
    /// and awaited to its first frame unless `waitForReady` is false.
    /// The clip is 1 s (30 frames) — ample for rate/position assertions
    /// and lighter on the gate's parallel encoders. The ready wait is
    /// generous (30 s): under the gate's parallel load first frames arrive
    /// late, but they arrive. Returns the seam handle and its `@testable`
    /// session.
    private func makeSpeedClip(
        at speed: MediaPlaybackSpeed,
        waitForReady: Bool = true
    ) async throws -> (any MediaPlayback, AVMediaPlayback) {
        let url = try await fixture.writeShortMP4WithAudio(
            named: "speed-clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 30
        )
        let handle = try #require(await service.startPlayback(for: makeItem(url), at: speed))
        let session = try #require(handle as? AVMediaPlayback)
        if let view = handle.makeDisplayView() as? NSView {
            windowHost.host(view)
        }
        if waitForReady {
            let ready = await nextEvent(
                of: handle,
                where: { $0 == .readyForDisplay },
                timeout: 30
            )
            try #require(ready == .readyForDisplay, "the fixture session must reach its first frame")
        }
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

    // MARK: Start-at-speed (S12 — the §3 ordering pin)

    /// §10.2 (S12, design §3) — a session started at `.double` begins at
    /// rate 2: the initial play call *is* at the selected speed (the rate
    /// is part of "ready to play"), asserted immediately after
    /// `startPlayback` returns through `@testable` internals (the D25
    /// unmuted-start route) — no 1× beat exists to observe — and the rate
    /// holds through the first frame.
    @Test func startAtDoubleBeginsAtRateTwo() async throws {
        let (handle, session) = try await makeSpeedClip(at: .double, waitForReady: false)
        defer { handle.stop(); windowHost.close() }
        #expect(
            session.player.rate == 2,
            "the start call is at the selected speed — no 1× beat (S12, design §3 ordering)"
        )
        let ready = await nextEvent(of: handle, where: { $0 == .readyForDisplay }, timeout: 30)
        try #require(ready == .readyForDisplay, "the fixture session must reach its first frame")
        #expect(session.player.rate == 2, "the rate holds through the first frame (S12)")
    }

    /// §10.2 (S15) — the explicit pitch pin: the item is created with
    /// `audioTimePitchAlgorithm == .spectral` — never the OS default (an
    /// OS default is not a contract, design §0 fact 2).
    @Test func audioTimePitchAlgorithmIsPinnedSpectralAtCreation() async throws {
        let (handle, session) = try await makeSpeedClip(at: .normal)
        defer { handle.stop(); windowHost.close() }
        #expect(
            session.playerItem.audioTimePitchAlgorithm == .spectral,
            "the pitch pin is explicit at item creation, before any audio renders (S15)"
        )
    }

    // MARK: Applying the selection (S10, S11)

    /// §10.2 (S10) — `setPlaybackSpeed` while playing: the rate write
    /// bites in the same main-actor turn and the position is untouched —
    /// a rate change only: no restart, no seek (the playhead stays
    /// continuous within one frame duration; the clock advances on its
    /// own thread between the reads).
    @Test func speedChangeWhilePlayingIsAnInTurnRateWrite() async throws {
        let (handle, session) = try await makeSpeedClip(at: .normal)
        defer { handle.stop(); windowHost.close() }
        let before = session.player.currentTime().seconds
        session.setPlaybackSpeed(.double)
        #expect(session.player.rate == 2, "the rate write bites in the same turn (S10)")
        let after = session.player.currentTime().seconds
        #expect(
            after.isFinite && abs(after - before) <= 1.0 / 30.0,
            "the command is a rate change only — no restart, no position change (S10)"
        )
    }

    /// §10.2 (S11) — `setPlaybackSpeed` while paused: the frozen frame
    /// stands (rate 0 — the write is skipped) and a later `resume()` plays
    /// at the remembered selection.
    @Test func speedChangeWhilePausedIsRememberedAndAppliesOnResume() async throws {
        let (handle, session) = try await makeSpeedClip(at: .normal)
        defer { handle.stop(); windowHost.close() }
        handle.pause()
        #expect(session.player.rate == 0, "arrange: pause is the rate-0 write (design §8(2))")
        session.setPlaybackSpeed(.double)
        #expect(session.player.rate == 0, "paused — the write is skipped, the frozen frame stands (S11)")
        handle.resume()
        #expect(session.player.rate == 2, "resume plays at the remembered selection (S11)")
    }

    // MARK: Preservation (S13, S14)

    /// §10.2 (S14) — `restart()` plays at the selection: seek-to-zero
    /// then the rate write at the session's speed (design §0 fact 1's
    /// seek-then-rate ordering) — a 2× batch loops at 2×.
    @Test func restartPlaysAtTheSelectedSpeed() async throws {
        let (handle, session) = try await makeSpeedClip(at: .double)
        defer { handle.stop(); windowHost.close() }
        handle.restart()
        #expect(session.player.rate == 2, "the restart plays at the selection (S14)")
        let landed = await waitForLanding(session, near: 0, within: 0.2)
        #expect(landed, "the restart seeked back toward the beginning (design §5)")
    }

    /// §10.2 (S13) — a seek leaves the selection untouched: a playing
    /// video keeps its pace (rate 2) across an `.exact` seek, and the
    /// seek lands at the requested point.
    @Test func seekLeavesTheSelectedSpeedUntouched() async throws {
        let (handle, session) = try await makeSpeedClip(at: .double)
        defer { handle.stop(); windowHost.close() }
        session.seek(to: 0.5, tolerance: .exact)
        let landed = await waitForLanding(session, near: 0.5, within: 1.0 / 30.0)
        #expect(landed, "the seek must land at the requested point (S7)")
        #expect(
            session.player.rate == 2,
            "a playing video keeps its pace across a seek — never resets to 1× (S13)"
        )
    }

    // MARK: Session teardown

    /// §10.2 (E2-S3 §10.2 patterns carry) — `stop()` leaves no rate work
    /// pending at any speed: silent, item detached, synchronously.
    @Test func stopSilencesTheSessionAtAnySpeed() async throws {
        let (handle, session) = try await makeSpeedClip(at: .double)
        defer { windowHost.close() }
        handle.stop()
        #expect(session.player.rate == 0, "stop is silent — no rate work pending (design §3 brace 1)")
        #expect(session.player.currentItem == nil, "the item is detached (design §2)")
    }

    // MARK: Stub/wiring rows (task 4.4 — the composition's wiring)

    /// §10.2 (task 4.4) — the stub service records the `at:` parameter of
    /// every start and the stub handle records every `setPlaybackSpeed`
    /// command (house pattern): the wiring the composition tests assert.
    @Test func stubRecordsTheStartSpeedAndSpeedCommands() async throws {
        let stub = StubMediaPlayerService()
        let url = try await fixture.writeShortMP4WithAudio(
            named: "stub-clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32
        )
        let item = makeItem(url)

        let anyHandle = try #require(await stub.startPlayback(for: item, at: .double))
        #expect(stub.startSpeeds == [.double], "the start speed is recorded for wiring tests")

        let stubHandle = try #require(anyHandle as? StubMediaPlayback)
        stubHandle.setPlaybackSpeed(.half)
        stubHandle.setPlaybackSpeed(.quarter)
        #expect(
            stubHandle.speedSelections == [.half, .quarter],
            "the speed commands are recorded, in call order (task 4.4)"
        )
    }
}

/// The §8(1) rate-change and §8(3) step-path budgets, measured from
/// tooling (RNF-02): the selection/step is issued and the `AVPlayer.rate`
/// write completes in the same main-actor turn — ≤ 16 ms (one display
/// frame) per input. XCTest `measure` is the design's one deliberate
/// Swift Testing exception (task 4.2); the measured numbers are recorded
/// as story evidence from tooling (task 10.5).
///
/// The methods are `nonisolated` on purpose: the seam is `@MainActor`, so
/// each measured cycle runs as a main-actor task while the synchronous
/// (measure) body services the main actor through the run loop — a
/// semaphore bridge would starve the very executor the session needs (the
/// D25 test-infrastructure pattern, `MediaPlayerPerformanceTests`). For
/// the same reason, the fixture, service, session, view model, and window
/// are released only inside main-actor tasks (the deallocating-deinit
/// SIGABRT lesson recorded there).
final class AVMediaPlaybackSpeedPerformanceTests: XCTestCase {
    /// One rate-change command cycle, run synchronously for the measure
    /// block: a main-actor task issues `setPlaybackSpeed` to the live,
    /// playing session and reads back the rate (the synchronous bite),
    /// while this body pumps the run loop. Alternating presets force a
    /// real rate write every pass. Returns the elapsed milliseconds.
    @discardableResult
    private nonisolated func runOneRateChangeCycle(
        box: SpeedBox,
        target: MediaPlaybackSpeed,
        log: String
    ) -> Double? {
        let cycleBox = SpeedCycleBox()
        let workTask = Task { @MainActor in
            Self.runCycle(cycleBox: cycleBox, box: box, target: target)
        }
        let deadline = Date().addingTimeInterval(30)
        while cycleBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        workTask.cancel()
        guard cycleBox.done else {
            Self.recordEvidence("cycle aborted: never completed within 30 s", to: log)
            XCTFail("the rate-change cycle never completed within 30 s")
            return nil
        }
        if let failure = cycleBox.failure {
            Self.recordEvidence("cycle failed: \(failure)", to: log)
            XCTFail(failure)
            return nil
        }
        return cycleBox.elapsedMs
    }

    /// The seam work of one cycle, on the main actor: the command and the
    /// synchronous rate-write readback — the §8(1) measured window is the
    /// command → rate-write interval itself.
    @MainActor
    private static func runCycle(cycleBox: SpeedCycleBox, box: SpeedBox, target: MediaPlaybackSpeed) {
        guard let session = box.session else {
            cycleBox.failure = "the session was already released"
            cycleBox.done = true
            return
        }
        let started = Date()
        session.setPlaybackSpeed(target)
        let rate = session.player.rate
        cycleBox.elapsedMs = Date().timeIntervalSince(started) * 1000
        if rate == target.rawValue {
            cycleBox.done = true
        } else {
            cycleBox.failure = "the rate write did not bite in the command's turn"
            cycleBox.done = true
        }
    }

    /// The §8(1) budget, measured: warm-up, a deterministic single-pass
    /// catch under the 16 ms in-turn budget, then the `measure` block
    /// recording the trend as tooling evidence.
    nonisolated func testRateChangeCommandBudgetThroughPlayerSeam() {
        let log = "e3s2-rate-change-budget-evidence.txt"
        guard let box = buildPlayingSession() else { return }
        Self.resetEvidenceFile(
            named: log,
            title: "e3-s2 §8(1) rate-change command → rate-write budget, measured from tooling"
        )

        // Warm-up pass: the budget covers the warm app's command path.
        if let warmupMs = runOneRateChangeCycle(box: box, target: .double, log: log) {
            Self.recordEvidence("warm-up: \(String(format: "%.2f", warmupMs)) ms", to: log)
        }

        // Deterministic single-pass catch: each command must land its
        // rate write in the same main-actor turn under one display frame
        // (design §8(1)); the measure block records the trend.
        for (pass, target) in [MediaPlaybackSpeed.double, .half, .normal].enumerated() {
            guard let elapsedMs = runOneRateChangeCycle(box: box, target: target, log: log) else { return }
            Self.recordEvidence(
                "pass \(pass + 1) (\(target.rawValue)×): \(String(format: "%.2f", elapsedMs)) ms",
                to: log
            )
            XCTAssertLessThan(elapsedMs, 16, "16 ms in-turn rate-change budget (design §8(1)) violated")
        }

        // Tooling evidence: measured over iterations of the same cycle.
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        var measureTarget = MediaPlaybackSpeed.oneAndHalf
        measure(options: options) {
            let elapsedMs = runOneRateChangeCycle(box: box, target: measureTarget, log: log) ?? -1
            Self.recordEvidence(
                "measure iteration (\(measureTarget.rawValue)×): \(String(format: "%.2f", elapsedMs)) ms",
                to: log
            )
            measureTarget = measureTarget == .oneAndHalf ? .normal : .oneAndHalf
        }

        releaseOnActor(box)
    }

    /// One keyboard-step cycle, run synchronously for the measure block:
    /// a main-actor task issues one ladder step through the real view
    /// model (O(1) ladder move + O(1) observable write + synchronous rate
    /// write — §8(3)) while this body pumps the run loop. Alternating
    /// directions keeps the walk mid-ladder; at the ends the clamp makes
    /// repeats idempotent (still a real command).
    @discardableResult
    private nonisolated func runOneStepCycle(box: SpeedBox, up: Bool, log: String) -> Double? {
        let cycleBox = SpeedCycleBox()
        let workTask = Task { @MainActor in
            Self.runStepCycle(cycleBox: cycleBox, box: box, up: up)
        }
        let deadline = Date().addingTimeInterval(30)
        while cycleBox.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        workTask.cancel()
        guard cycleBox.done else {
            Self.recordEvidence("step cycle aborted: never completed within 30 s", to: log)
            XCTFail("the step cycle never completed within 30 s")
            return nil
        }
        if let failure = cycleBox.failure {
            Self.recordEvidence("step cycle failed: \(failure)", to: log)
            XCTFail(failure)
            return nil
        }
        return cycleBox.elapsedMs
    }

    /// The step-path work of one cycle, on the main actor: one route call
    /// through the guard matrix, the ladder move, the observable writes,
    /// and the live session's synchronous rate write.
    @MainActor
    private static func runStepCycle(cycleBox: SpeedCycleBox, box: SpeedBox, up: Bool) {
        guard let viewModel = box.viewModel else {
            cycleBox.failure = "the view model was already released"
            cycleBox.done = true
            return
        }
        let started = Date()
        if up {
            viewModel.stepSpeedUpByKeyboard()
        } else {
            viewModel.stepSpeedDownByKeyboard()
        }
        cycleBox.elapsedMs = Date().timeIntervalSince(started) * 1000
        cycleBox.done = true
    }

    /// The §8(3) step-path budget, measured: warm-up, single-pass catches
    /// under 16 ms, then the `measure` block as tooling evidence.
    nonisolated func testKeyboardStepPathBudgetThroughTheFeedViewModel() {
        let log = "e3s2-step-path-budget-evidence.txt"
        guard let box = buildViewModelWithSession() else { return }
        Self.resetEvidenceFile(
            named: log,
            title: "e3-s2 §8(3) keyboard step-path budget, measured from tooling"
        )

        if let warmupMs = runOneStepCycle(box: box, up: true, log: log) {
            Self.recordEvidence("step warm-up: \(String(format: "%.2f", warmupMs)) ms", to: log)
        }

        // Single-pass catches: up to 2×, back down — each press applied
        // within one display frame (design §8(3)).
        for (pass, up) in [true, true, false, false].enumerated() {
            guard let elapsedMs = runOneStepCycle(box: box, up: up, log: log) else { return }
            Self.recordEvidence(
                "step pass \(pass + 1) (up: \(up)): \(String(format: "%.2f", elapsedMs)) ms",
                to: log
            )
            XCTAssertLessThan(elapsedMs, 16, "16 ms step-path budget (design §8(3)) violated")
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        var measureUp = true
        measure(options: options) {
            let elapsedMs = runOneStepCycle(box: box, up: measureUp, log: log) ?? -1
            Self.recordEvidence(
                "step measure iteration (up: \(measureUp)): \(String(format: "%.2f", elapsedMs)) ms",
                to: log
            )
            measureUp.toggle()
        }

        releaseOnActor(box)
    }

    // MARK: Arrange (run-loop-pumped, the D25 pattern)

    /// Builds the fixture clip and a live, playing, first-frame-ready
    /// session through the real service (both on the main actor, pumped
    /// through the run loop like every other main-actor hop here).
    private nonisolated func buildPlayingSession() -> SpeedBox? {
        let box = SpeedBox()
        let buildTask = Task { @MainActor in
            let fixture = MediaFixture()
            let clipURL = fixture.root.appending(path: "rate-clip.mp4")
            do {
                try await MediaFixture.writeShortMP4(
                    to: clipURL,
                    pixelWidth: 320,
                    pixelHeight: 180,
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
            let item = MediaItem(id: clipURL, url: clipURL, name: "rate-clip.mp4", kind: .video)
            let service = AVMediaPlayerService()
            box.service = service
            guard let handle = await service.startPlayback(for: item, at: .normal) else {
                box.failure = "startPlayback answered nil for a playable clip"
                box.done = true
                return
            }
            guard let session = handle as? AVMediaPlayback else {
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
            box.done = true
        }
        pumpUntilDone(box, deadline: 120)
        buildTask.cancel()
        return validated(box, require: { $0.session }, message: "the performance session must be live and playing")
    }

    /// Builds the fixture clip and a real view model (real service, the
    /// scripted fixture repository) whose session is installed and
    /// displayed — the honest step-path subject: route call → policy →
    /// live handle command (§8(3)).
    private nonisolated func buildViewModelWithSession() -> SpeedBox? {
        let box = SpeedBox()
        let buildTask = Task { @MainActor in
            let fixture = MediaFixture()
            let clipURL = fixture.root.appending(path: "step-clip.mp4")
            do {
                try await MediaFixture.writeShortMP4(
                    to: clipURL,
                    pixelWidth: 320,
                    pixelHeight: 180,
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
            let item = MediaItem(id: clipURL, url: clipURL, name: "step-clip.mp4", kind: .video)
            let collection = MediaCollection(
                folderURL: fixture.root,
                items: [item],
                startIndex: 0,
                capturedAt: Date()
            )
            let service = AVMediaPlayerService()
            box.service = service
            let viewModel = FeedViewModel(
                mediaPlayerService: service,
                mediaFolderRepository: SpeedFixtureRepository(collection: collection),
                mediaPreviewService: StubMediaPreviewService()
            )
            box.viewModel = viewModel
            await viewModel.handle(entryAction: EntryAction(enteredURL: fixture.root))
            // The session is installed and displayed exactly when the
            // current video's bar model exists (the `.readyForDisplay`
            // swap builds it hidden-at-rest — design §7).
            let deadline = Date().addingTimeInterval(60)
            while viewModel.controlBarModel == nil, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard viewModel.controlBarModel != nil else {
                box.failure = "the session never installed and displayed"
                box.done = true
                return
            }
            box.done = true
        }
        pumpUntilDone(box, deadline: 120)
        buildTask.cancel()
        return validated(
            box,
            require: { $0.viewModel },
            message: "the view model must hold a displayed session"
        )
    }

    /// Pumps the run loop until the box reports done or the deadline
    /// passes (seconds).
    private nonisolated func pumpUntilDone(_ box: SpeedBox, deadline seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while box.done == false, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
    }

    /// Shared validation for the arrange boxes: fail loudly on a recorded
    /// failure and require the key object to exist.
    private nonisolated func validated(
        _ box: SpeedBox,
        require hasKey: (SpeedBox) -> AnyObject?,
        message: String
    ) -> SpeedBox? {
        if let failure = box.failure {
            XCTFail(failure)
            return nil
        }
        guard hasKey(box) != nil else {
            XCTFail(message)
            return nil
        }
        return box
    }

    /// The session, window, view model, and service are released only on
    /// the actor (the class comment explains why this cannot be left to
    /// the nonisolated method's scope end).
    private nonisolated func releaseOnActor(_ box: SpeedBox) {
        let endBox = SpeedCycleBox()
        let endTask = Task { @MainActor in
            box.host?.close()
            box.host = nil
            box.viewModel = nil
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

    // MARK: Evidence capture (task 10.5)

    /// The scratch file the measured numbers land in — the app cache
    /// directory (resolves through the sandbox container when present).
    /// One file per test so the suite's two measures never clobber each
    /// other. Test-only scratch: timing numbers, never committed.
    private nonisolated static func evidenceFile(named name: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent(name)
    }

    private nonisolated static func resetEvidenceFile(named name: String, title: String) {
        try? "\(title)\n".write(to: evidenceFile(named: name), atomically: true, encoding: .utf8)
    }

    /// Appends one measured line to the scratch evidence file (best-effort:
    /// a failed write must not fail the measurement itself).
    private nonisolated static func recordEvidence(_ line: String, to name: String) {
        let url = evidenceFile(named: name)
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
private final class SpeedBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var fixture: MediaFixture?
    var service: AVMediaPlayerService?
    var session: AVMediaPlayback?
    var viewModel: FeedViewModel?
    var host: PlaybackWindowHost?
}

/// Per-cycle result box (same discipline as `SpeedBox`).
private final class SpeedCycleBox: @unchecked Sendable {
    var done = false
    var failure: String?
    var elapsedMs = 0.0
}

/// Scripted repository double for the step-path arrange: answers with the
/// one fixture collection (the `ScriptedMediaFolderRepository` shape,
/// local to this file). Zero I/O.
private final class SpeedFixtureRepository: MediaFolderRepository {
    private let collection: MediaCollection?

    init(collection: MediaCollection?) {
        self.collection = collection
    }

    func prepareCollection(forEntryAt _: EntryAction) async -> MediaCollection? {
        collection
    }

    func wiringProbe() async -> String {
        "SpeedFixtureRepository"
    }
}
