//
//  MediaPreviewPerformanceTests.swift
//  InstantPlayerTests
//
//  Display budget through the preview seam, measured (E2-S2, design
//  §8(1) — RNF-02).
//

@testable import InstantPlayer
import XCTest

/// The generated-fixture bundle: one real 720p video item and two real
/// stills (the typical budget's 24 MP top and a 48 MP heavy case).
private struct PerfFixtures {
    let videoItem: MediaItem
    let stillItem: MediaItem
    let heavyItem: MediaItem
}

/// The §8(1) display budget, measured from tooling: one page settle's
/// extraction (decode → downsample → encode) must stay ≤ 300 ms for
/// typical media (≤ 1080p clip, ≤ 24 MP still) and ≤ 1 s for heavy media,
/// warm, on Apple-silicon reference hardware; a cached preview must
/// redisplay within one frame (< 16 ms). XCTest `measure` is the
/// design's one deliberate Swift Testing exception (tasks.md 6.2); the
/// measured numbers are recorded as story evidence from tooling (task 9).
final class MediaPreviewPerformanceTests: XCTestCase {
    /// Throwaway fixture tree, removed when the test case deallocates
    /// (the E2-S1 §9.1 teardown pattern).
    private let fixture = MediaFixture()

    func testDisplayBudgetThroughPreviewSeam() {
        let service = AVMediaPreviewService()
        guard let fixtures = buildFixtures() else { return }

        // Evidence capture: the gate log does not relay test-process
        // stdout, and the xcresult's measure values need extra tooling to
        // read — so the measured numbers are appended to this throwaway
        // scratch file (process temp dir, never committed) and quoted
        // verbatim as story evidence (tasks 6.5, 9.5).
        resetEvidenceFile()

        // Warm-up pass: framework cold-start is not the display budget's
        // subject — the budget covers the warm app's page-settle path.
        awaitSeam {
            _ = await service.preview(for: fixtures.videoItem)
            _ = await service.preview(for: fixtures.stillItem)
            _ = await service.preview(for: fixtures.heavyItem)
        }

        // Design §8(1) budgets the typical display at "≤ 300 ms p95", so
        // the typical cold passes are sampled at N = 20 (10 per typical
        // fixture — same fixtures, same extraction path, fixtures built
        // once above) and the p95 of the samples is asserted: the 19th of
        // 20 sorted times (sorted[18], nearest-rank p95 = ⌈0.95 × 20⌉ = 19)
        // must stay under budget — at most one pass of twenty may exceed
        // it. The heavy pass keeps its single-pass check (N = 1) against
        // the unchanged 1 s budget.
        var typicalColdPassTimes: [Double] = []
        for _ in 0 ..< 10 {
            typicalColdPassTimes.append(
                measureColdPass(
                    service: service,
                    item: fixtures.videoItem,
                    name: "300 ms typical (720p clip, design §8(1))"
                )
            )
            typicalColdPassTimes.append(
                measureColdPass(
                    service: service,
                    item: fixtures.stillItem,
                    name: "300 ms typical (24 MP still, design §8(1))"
                )
            )
        }
        XCTAssertLessThan(
            typicalColdPassTimes.sorted()[18],
            0.30,
            "300 ms typical p95 over 20 cold passes (design §8(1)) violated"
        )
        let heavyColdPassTime = measureColdPass(
            service: service,
            item: fixtures.heavyItem,
            name: "1 s heavy (48 MP still, design §8(1))"
        )
        XCTAssertLessThan(
            heavyColdPassTime,
            1.0,
            "1 s heavy (48 MP still, design §8(1)) violated"
        )

        // Tooling evidence: measured over iterations over the generated
        // fixtures — each pass discards, then extracts the typical pair.
        // Per-iteration wall times are printed so the measured numbers are
        // captured verbatim in the gate log (task 9's evidence source).
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(options: options) {
            let start = Date()
            awaitSeam {
                await service.discardPreviews()
                _ = await service.preview(for: fixtures.videoItem)
                _ = await service.preview(for: fixtures.stillItem)
            }
            let elapsed = Date().timeIntervalSince(start)
            recordEvidence("measure iteration: \(String(format: "%.1f", elapsed * 1000)) ms")
        }

        // Warm cache-hit path (design §8(1)): a cached preview must
        // redisplay within one frame (< 16 ms). Each pass primes the cache
        // once (cold), then times the re-request — the cache hit.
        assertWarmCacheHit(
            service: service,
            item: fixtures.videoItem,
            name: "cache-hit < 16 ms (720p clip, design §8(1))"
        )
        assertWarmCacheHit(
            service: service,
            item: fixtures.stillItem,
            name: "cache-hit < 16 ms (24 MP still, design §8(1))"
        )
        assertWarmCacheHit(
            service: service,
            item: fixtures.heavyItem,
            name: "cache-hit < 16 ms (48 MP still, design §8(1))"
        )
    }

    /// Builds the real-byte fixtures (design §10.2) inside the throwaway
    /// tree, off the main thread (the writers are `nonisolated`; the work
    /// joins on a semaphore). Returns nil — after failing — when a fixture
    /// did not materialize.
    private func buildFixtures() -> PerfFixtures? {
        let clipURL = fixture.root.appending(path: "clip-720p.mp4")
        let stillURL = fixture.root.appending(path: "still-24mp.jpg")
        let heavyURL = fixture.root.appending(path: "heavy-48mp.jpg")
        awaitSeam {
            try? await MediaFixture.writeOneFrameMP4(to: clipURL, pixelWidth: 1280, pixelHeight: 720)
            try? MediaFixture.writeImage(to: stillURL, pixelWidth: 6000, pixelHeight: 4000)
            try? MediaFixture.writeImage(to: heavyURL, pixelWidth: 8000, pixelHeight: 6000)
        }
        guard FileManager.default.fileExists(atPath: clipURL.path),
              FileManager.default.fileExists(atPath: stillURL.path),
              FileManager.default.fileExists(atPath: heavyURL.path)
        else {
            XCTFail("the performance fixtures must build and exist on disk")
            return nil
        }
        return PerfFixtures(
            videoItem: MediaItem(id: clipURL, url: clipURL, name: "clip-720p.mp4", kind: .video),
            stillItem: MediaItem(id: stillURL, url: stillURL, name: "still-24mp.jpg", kind: .image),
            heavyItem: MediaItem(id: heavyURL, url: heavyURL, name: "heavy-48mp.jpg", kind: .image)
        )
    }

    /// One cold pass through the seam (discard → extract), returning the
    /// measured time for the caller's budget assertion (the p95-over-passes
    /// form of design §8(1); the E2-S1 single-pass precedent, per budget).
    private func measureColdPass(service: AVMediaPreviewService, item: MediaItem, name: String) -> Double {
        let start = Date()
        awaitSeam {
            await service.discardPreviews()
            _ = await service.preview(for: item)
        }
        let elapsed = Date().timeIntervalSince(start)
        recordEvidence("cold-pass \(name): \(String(format: "%.1f", elapsed * 1000)) ms")
        return elapsed
    }

    /// One warm cache-hit pass through the seam: prime the cache once
    /// (discard → extract), then re-request the same item without
    /// discarding — the hit must stay under the one-frame redisplay budget
    /// (< 16 ms, design §8(1)).
    private func assertWarmCacheHit(service: AVMediaPreviewService, item: MediaItem, name: String) {
        awaitSeam {
            await service.discardPreviews()
            _ = await service.preview(for: item)
        }
        let start = Date()
        awaitSeam {
            _ = await service.preview(for: item)
        }
        let elapsed = Date().timeIntervalSince(start)
        recordEvidence("\(name): \(String(format: "%.1f", elapsed * 1000)) ms")
        XCTAssertLessThan(elapsed, 0.016, "\(name) violated")
    }

    // MARK: Evidence capture (tasks 6.5, 9.5)

    /// The scratch file the measured numbers land in — the app cache
    /// directory (resolves through the sandbox container when present),
    /// truncated at test start so every gate run records fresh. Test-only
    /// scratch: timing numbers, never committed.
    private static var evidenceFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("e2s2-display-budget-evidence.txt")
    }

    private func resetEvidenceFile() {
        try? "e2-s2 display budget, measured from tooling\n".write(
            to: Self.evidenceFile,
            atomically: true,
            encoding: .utf8
        )
    }

    /// Appends one measured line to the scratch evidence file (best-effort:
    /// a failed write must not fail the measurement itself).
    private func recordEvidence(_ line: String) {
        let url = Self.evidenceFile
        if let handle = FileHandle(forWritingAtPath: url.path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write((line + "\n").data(using: .utf8) ?? Data())
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Runs one async body to completion (the E2-S1 semaphore bridge —
    /// `measure` blocks must stay synchronous).
    private func awaitSeam(_ body: @escaping @Sendable () async -> Void) {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await body()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 120)
    }
}
