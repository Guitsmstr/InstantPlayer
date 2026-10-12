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
/// warm, on Apple-silicon reference hardware. XCTest `measure` is the
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

        // Deterministic single-pass catch: each cold (cache-discarded)
        // extraction must stay under its budget; the measure block below
        // records the trend as tooling evidence.
        assertColdPass(
            service: service,
            item: fixtures.videoItem,
            budget: 0.30,
            name: "300 ms typical (720p clip, design §8(1))"
        )
        assertColdPass(
            service: service,
            item: fixtures.stillItem,
            budget: 0.30,
            name: "300 ms typical (24 MP still, design §8(1))"
        )
        assertColdPass(
            service: service,
            item: fixtures.heavyItem,
            budget: 1.0,
            name: "1 s heavy (48 MP still, design §8(1))"
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

    /// One cold pass through the seam (discard → extract), asserted under
    /// the budget (the E2-S1 single-pass precedent).
    private func assertColdPass(service: AVMediaPreviewService, item: MediaItem, budget: Double, name: String) {
        let start = Date()
        awaitSeam {
            await service.discardPreviews()
            _ = await service.preview(for: item)
        }
        let elapsed = Date().timeIntervalSince(start)
        recordEvidence("cold-pass \(name): \(String(format: "%.1f", elapsed * 1000)) ms")
        XCTAssertLessThan(elapsed, budget, "\(name) violated")
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
