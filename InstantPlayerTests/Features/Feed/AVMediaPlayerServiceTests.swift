//
//  AVMediaPlayerServiceTests.swift
//  InstantPlayerTests
//
//  Playback-seam suite over real fixture bytes (E2-S3, design §10.2 —
//  S1, S3, S5, S9–S11, S14, S15; §3 braces, §8(2)–§8(3)).
//

import AppKit
import AVFoundation
@testable import InstantPlayer
import QuartzCore
import Testing

/// Real-bytes rows through the frozen seam only (design §10.2): every test
/// writes its own throwaway folder (`MediaFixture`, torn down on deinit)
/// with a real short multi-frame MP4 (`AVAssetWriter`), then drives the
/// `AVMediaPlayerService`/`AVMediaPlayback` conformance. The unmuted start
/// (S3) is asserted through `@testable` internals — the design's noted
/// route, since the frozen seam contract deliberately carries no
/// state-query members (task 10's deviations list notes this).
/// Suites are `@MainActor`: the conformance is MainActor-isolated
/// (E2-S3 design §1.2).
@MainActor
struct AVMediaPlayerServiceTests {
    private let fixture = MediaFixture()
    private let service = AVMediaPlayerService()

    private func makeItem(_ url: URL) -> MediaItem {
        MediaItem(id: url, url: url, name: url.lastPathComponent, kind: .video)
    }

    /// Waits for the stream's first event satisfying `predicate`, bounded
    /// by `timeout` so a missing event fails the test instead of hanging
    /// the gate (Swift Testing has no built-in expectation timeout). The
    /// test body is the stream's only consumer — the view model is not
    /// involved in the seam rows.
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

    /// Waits until `condition` holds, spinning the main actor (the house
    /// `waitFor` pattern), with a bounded budget.
    private func waitFor(
        _ condition: () async -> Bool,
        spins limit: Int = 10000,
        _ message: String
    ) async -> Bool {
        var spins = 0
        while await condition() == false {
            await Task.yield()
            spins += 1
            if spins >= limit {
                Issue.record("\(message)")
                return false
            }
        }
        return true
    }

    /// §10.2 row 1 (S1, S3) — a real clip starts a session that reaches
    /// its first frame (`.readyForDisplay`, the poster→player swap gate)
    /// while auto-playing: audio unmuted, `volume` untouched, rate 1 —
    /// asserted through `@testable` internals (design §10.2's noted route).
    @Test func realClipStartsAutoPlayingReadyAndUnmuted() async throws {
        let url = try await fixture.writeShortMP4(named: "clip.mp4", pixelWidth: 64, pixelHeight: 32)
        let item = makeItem(url)
        let host = PlaybackWindowHost()
        defer { host.close() }

        let handle = try #require(await service.startPlayback(for: item))
        if let view = handle.makeDisplayView() as? NSView {
            host.host(view)
        }

        let event = await nextEvent(of: handle, where: { $0 == .readyForDisplay })
        #expect(event == .readyForDisplay, "the layer's first frame must arrive (design §4 swap gate)")

        let session = try #require(handle as? AVMediaPlayback)
        #expect(session.player.isMuted == false, "auto-play must be unmuted (S3)")
        #expect(session.player.volume == 1.0, "volume must be untouched (S3 — app-level volume is E3-S3)")
        #expect(session.player.rate == 1, "the session must auto-play (S1)")
    }

    /// §10.2 rows 2–3 (S5, S6) — `pause()` freezes the current time and
    /// bites synchronously (rate 0 before it returns, design §8(2));
    /// `resume()` continues from the frozen point. The clip is long (2 s)
    /// and the sleeps short, so a slow `.readyForDisplay` under the gate's
    /// parallel load can never park the session at its end mid-test — the
    /// resumed session must have real time ahead to advance into.
    @Test func pauseFreezesTimeResumeContinues() async throws {
        let url = try await fixture.writeShortMP4(
            named: "clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 60
        )
        let item = makeItem(url)
        let host = PlaybackWindowHost()
        defer { host.close() }

        let handle = try #require(await service.startPlayback(for: item))
        if let view = handle.makeDisplayView() as? NSView {
            host.host(view)
        }
        _ = await nextEvent(of: handle, where: { $0 == .readyForDisplay })

        try await Task.sleep(for: .milliseconds(100))
        let session = try #require(handle as? AVMediaPlayback)
        let frozen = session.player.currentTime().seconds

        session.pause()
        #expect(session.player.rate == 0, "pause must bite synchronously (design §8(2))")
        try await Task.sleep(for: .milliseconds(100))
        #expect(
            abs(session.player.currentTime().seconds - frozen) < 0.001,
            "the paused frame must not advance (S5)"
        )

        session.resume()
        #expect(session.player.rate == 1, "resume must restore playback (S5)")
        try await Task.sleep(for: .milliseconds(200))
        #expect(
            session.player.currentTime().seconds > frozen,
            "time must continue from the frozen point (S5)"
        )
    }

    /// §10.2 row 4 (S11's trigger) — the short clip plays to its natural
    /// end and emits `.reachedEnd`; the item parks at its end
    /// (`actionAtItemEnd = .none` — the loop support, design §5).
    @Test func shortClipNaturallyReachesEnd() async throws {
        let url = try await fixture.writeShortMP4(
            named: "clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 6
        )
        let item = makeItem(url)
        let host = PlaybackWindowHost()
        defer { host.close() }

        let handle = try #require(await service.startPlayback(for: item))
        if let view = handle.makeDisplayView() as? NSView {
            host.host(view)
        }

        let event = await nextEvent(of: handle, where: { $0 == .reachedEnd })
        #expect(event == .reachedEnd, "the natural end must emit .reachedEnd (S11's trigger)")

        let session = try #require(handle as? AVMediaPlayback)
        #expect(
            session.player.currentTime().seconds >= 0.15,
            "the item parks at its end (actionAtItemEnd = .none, design §5)"
        )
    }

    /// §10.2 row 5 (S11's mechanism) — after the end, `restart()` seeks
    /// back toward the beginning and plays: the honest restart of the same
    /// session, not a gapless cycle (design §5).
    @Test func restartReturnsNearZeroAndPlays() async throws {
        let url = try await fixture.writeShortMP4(
            named: "clip.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 6
        )
        let item = makeItem(url)
        let host = PlaybackWindowHost()
        defer { host.close() }

        let handle = try #require(await service.startPlayback(for: item))
        if let view = handle.makeDisplayView() as? NSView {
            host.host(view)
        }
        _ = await nextEvent(of: handle, where: { $0 == .reachedEnd })

        let session = try #require(handle as? AVMediaPlayback)
        session.restart()
        var settled = false
        for _ in 0 ..< 1000 {
            if session.player.rate == 1, session.player.currentTime().seconds < 0.15 {
                settled = true
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(settled, "restart() must seek back toward the beginning and play (S11, design §5)")
    }

    /// §10.2 row 6 (S14 — D20's honest declared-type contract pinned):
    /// text bytes named `.mp4` can only fail to load → the unified `nil`.
    @Test func mislabeledFileAnswersNil() async throws {
        let junk = "this is plain text, not an ISO-BMFF track file"
        let url = try fixture.writeFile("fake.mp4", bytes: Array(junk.utf8))
        let item = makeItem(url)

        let handle = await service.startPlayback(for: item)

        #expect(handle == nil, "mislabeled content must answer nil (S14)")
    }

    /// §10.2 row 7 (S15) — a vanished file (the snapshot's stale item)
    /// answers `nil`, the same unified failure answer.
    @Test func vanishedFileAnswersNil() async {
        let url = fixture.root.appending(path: "ghost.mp4")
        let item = makeItem(url)

        let handle = await service.startPlayback(for: item)

        #expect(handle == nil, "a missing file must answer nil (S15)")
    }

    /// §10.2 row 8 (design §3 brace 1) — `stop()` finishes the stream (the
    /// drain below terminates), detaches the item, silences the player,
    /// and releases the display view: nothing usable after stop.
    @Test func stopFinishesStreamDetachesAndReleases() async throws {
        let url = try await fixture.writeShortMP4(named: "clip.mp4", pixelWidth: 64, pixelHeight: 32)
        let item = makeItem(url)

        let handle = try #require(await service.startPlayback(for: item))
        let session = try #require(handle as? AVMediaPlayback)
        session.stop()

        let drained = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                for await _ in session.events {} // terminates iff the stream finished
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
        #expect(drained, "stop() must finish the event stream (design §3 brace 1)")
        #expect(session.player.currentItem == nil, "stop() detaches the item (design §2)")
        #expect(session.player.rate == 0, "stop() is silent (S9, design §8(2))")

        let view = try #require(session.makeDisplayView() as? NSView)
        let layer = view.layer?.sublayers?.compactMap { $0 as? AVPlayerLayer }.first
        #expect(layer != nil, "the host view carries the session's layer")
        #expect(layer?.player == nil, "the display view is released — the layer shows nothing (design §3)")
    }

    /// §10.2 row 9 (design §8(3) — exactly one live player): the next
    /// `startPlayback` supersedes and tears the previous session down —
    /// silent, detached, stream finished — while the new one is live.
    @Test func supersedingStartTearsThePreviousSessionDown() async throws {
        let urlA = try await fixture.writeShortMP4(
            named: "a.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 30
        )
        let urlB = try await fixture.writeShortMP4(
            named: "b.mp4",
            pixelWidth: 64,
            pixelHeight: 32,
            frameCount: 30
        )

        let first = try #require(await service.startPlayback(for: makeItem(urlA)))
        let second = try #require(await service.startPlayback(for: makeItem(urlB)))
        #expect(first !== second, "each start vends its own session")

        let firstSession = try #require(first as? AVMediaPlayback)
        let secondSession = try #require(second as? AVMediaPlayback)

        #expect(firstSession.player.currentItem == nil, "the superseded session is detached")
        #expect(firstSession.player.rate == 0, "the superseded session is silent")
        #expect(
            secondSession.player.currentItem != nil,
            "exactly one live player — the new session (design §8(3))"
        )

        let drained = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                for await _ in firstSession.events {} // terminates iff the stream finished
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
        #expect(drained, "the superseded session's stream finished (design §3 brace 1)")
    }
}

/// A small on-screen borderless window hosting a session's display view:
/// `AVPlayerLayer.isReadyForDisplay` is the first-frame gate (E2-S3 design
/// §0.3, §4), and the honest state under test is a displayed session.
/// Created and closed on the main actor; tests close it via `defer`.
/// Shared with the §8(1) performance test (same module, internal).
@MainActor
final class PlaybackWindowHost {
    private let window = NSWindow(
        contentRect: NSRect(x: 20, y: 20, width: 160, height: 90),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )

    init() {
        // ARC owns this window: the default `isReleasedWhenClosed = true`
        // makes `close()` over-release it, and the double release segfaults
        // AppKit's asynchronous window teardown — landing on whatever test
        // runs next.
        window.isReleasedWhenClosed = false
    }

    /// Puts `displayView` into the window's layer tree at full size and
    /// shows the window without requiring app activation.
    func host(_ displayView: NSView) {
        guard let contentView = window.contentView else { return }
        displayView.frame = contentView.bounds
        contentView.addSubview(displayView)
        window.orderFrontRegardless()
    }

    func close() {
        window.close()
    }
}
