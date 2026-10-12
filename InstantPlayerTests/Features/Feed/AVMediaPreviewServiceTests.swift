//
//  AVMediaPreviewServiceTests.swift
//  InstantPlayerTests
//
//  Preview-seam suite over real fixture bytes (E2-S2, design §10.2 —
//  S2, S3, S12, S13; §5.4 coalescing, cancellation, discard).
//

import AppKit
import ImageIO
@testable import InstantPlayer
import Testing

/// Real-bytes rows through the frozen seam only (design §10.2): every test
/// writes its own throwaway folder (`MediaFixture`, torn down on deinit)
/// with a real one-frame MP4 (`AVAssetWriter`) or real PNG/JPEG images,
/// then drives the `AVMediaPreviewService` actor through
/// `MediaPreviewService`.
struct AVMediaPreviewServiceTests {
    private let fixture = MediaFixture()
    private let service = AVMediaPreviewService()

    /// The display bound the conformance computes (§4.2) — the same
    /// formula in the same process, so assertions can pin the contract.
    private static let displayBoundPixels: Int = {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let largerAxisPoints = screen.map { max($0.frame.width, $0.frame.height) } ?? 1920
        let scale = screen?.backingScaleFactor ?? 2
        return Int((largerAxisPoints * scale * 2).rounded(.up))
    }()

    /// S3 — the video poster is honestly the first frame: a real
    /// one-frame MP4 yields a decodable preview at the frame's pixel size,
    /// served idempotently afterwards.
    @Test func videoPreviewIsTheFirstFrameOfARealMP4() async throws {
        let url = try await fixture.writeOneFrameMP4(pixelWidth: 64, pixelHeight: 32)
        let item = MediaItem(id: url, url: url, name: "clip.mp4", kind: .video)

        let preview = try #require(await service.preview(for: item))

        #expect(preview.pixelWidth == 64)
        #expect(preview.pixelHeight == 32)
        #expect(preview.imageData.isEmpty == false)
        let source = try #require(CGImageSourceCreateWithData(preview.imageData as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(width == 64, "the display bytes must decode back to the frame's width")
        #expect(height == 32, "the display bytes must decode back to the frame's height")
        #expect(await service.preview(for: item) == preview, "the seam is idempotent per item (design §3)")
    }

    /// S2 — an image preview keeps the source's aspect; a source below the
    /// display bound decodes at its own size.
    @Test func imagePreviewKeepsTheSourceAspect() async throws {
        let url = try fixture.writeImage(named: "wide.png", pixelWidth: 320, pixelHeight: 160)
        let item = MediaItem(id: url, url: url, name: "wide.png", kind: .image)

        let preview = try #require(await service.preview(for: item))

        #expect(preview.pixelWidth == 320)
        #expect(preview.pixelHeight == 160)
        let aspect = Double(preview.pixelWidth) / Double(preview.pixelHeight)
        #expect(abs(aspect - 2.0) < 0.01, "the produced aspect must be the source's (S2)")
    }

    /// §5.4 — the output is bounded by the display bound (the downsample
    /// proof): a 24 MP still never decodes past the bound, and whenever
    /// the source exceeds the bound the output is strictly smaller —
    /// aspect-preserving (S2).
    @Test func imagePreviewStaysWithinTheDisplayBound() async throws {
        let url = try fixture.writeImage(named: "large.jpg", pixelWidth: 6000, pixelHeight: 4000)
        let item = MediaItem(id: url, url: url, name: "large.jpg", kind: .image)

        let preview = try #require(await service.preview(for: item))

        #expect(
            max(preview.pixelWidth, preview.pixelHeight) <= Self.displayBoundPixels,
            "the output must respect the display bound (§4.2): \(preview.pixelWidth)×\(preview.pixelHeight)"
        )
        if Self.displayBoundPixels < 6000 {
            #expect(
                max(preview.pixelWidth, preview.pixelHeight) < 6000,
                "a source larger than the bound must be downsampled"
            )
        }
        let aspect = Double(preview.pixelWidth) / Double(preview.pixelHeight)
        #expect(abs(aspect - 1.5) < 0.01, "downsampling is aspect-preserving (S2)")
    }

    /// S13 — text bytes named `.mp4` (D20's honest declared-type
    /// contract): the decode can only fail → `nil` — no icon, no
    /// nearby-frame fallback.
    @Test func mislabeledVideoContentAnswersNil() async throws {
        let junk = "this is plain text, not an ISO-BMFF track file"
        let url = try fixture.writeFile("fake.mp4", bytes: Array(junk.utf8))
        let item = MediaItem(id: url, url: url, name: "fake.mp4", kind: .video)

        let preview = await service.preview(for: item)

        #expect(preview == nil, "mislabeled content must answer nil (S13)")
    }

    /// S12 — a vanished/unreadable file answers `nil`, display-time only.
    @Test func nonexistentURLAnswersNil() async {
        let url = fixture.root.appending(path: "ghost.mp4")
        let item = MediaItem(id: url, url: url, name: "ghost.mp4", kind: .video)

        let preview = await service.preview(for: item)

        #expect(preview == nil, "a missing file must answer nil (S12)")
    }

    /// §5.4 — N concurrent calls for one item share one extraction: every
    /// caller receives the same result, and a later call is the cached
    /// same value (idempotent per item).
    @Test func concurrentCallsForOneItemShareOneResult() async throws {
        let url = try await fixture.writeOneFrameMP4(pixelWidth: 64, pixelHeight: 32)
        let item = MediaItem(id: url, url: url, name: "clip.mp4", kind: .video)
        let previewService = service

        let results = await withTaskGroup(of: MediaPreview?.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { await previewService.preview(for: item) }
            }
            var collected: [MediaPreview?] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == 8)
        let shared = try #require(results.first)
        #expect(shared != nil)
        for result in results {
            #expect(result == shared, "every concurrent caller must receive the one shared result (§5.4)")
        }
        let cached = await service.preview(for: item)
        #expect(cached == shared, "a completed extraction is served idempotently from the cache")
    }

    /// §3/§5.4 — a cancelled task never completes its extraction: the task
    /// parks before the call, is cancelled, and is then released — it must
    /// answer `nil` even though the file decodes fine, and the seam stays
    /// healthy afterwards.
    @Test func cancelledTaskNeverCompletesItsExtraction() async throws {
        let url = try await fixture.writeOneFrameMP4(pixelWidth: 64, pixelHeight: 32)
        let item = MediaItem(id: url, url: url, name: "clip.mp4", kind: .video)
        let previewService = service
        let gate = StartGate()

        let task = Task { () -> MediaPreview? in
            await gate.wait()
            return await previewService.preview(for: item)
        }
        var spins = 0
        while await gate.isArmed == false {
            await Task.yield()
            spins += 1
            if spins >= 10000 {
                Issue.record("the probe task never reached the gate")
                await gate.release()
                _ = await task.value
                return
            }
        }
        task.cancel()
        await gate.release()

        let result = await task.value
        #expect(result == nil, "a cancelled call must not complete its extraction (design §3)")
        let healthy = await service.preview(for: item)
        #expect(healthy != nil, "the seam must stay usable after a cancelled call")
    }

    /// S9/§3 — `discardPreviews()` empties the cache: after the discard,
    /// the same URL re-extracts, proven by rewriting the file with
    /// different pixels between the calls.
    @Test func discardPreviewsEmptiesTheCache() async throws {
        let url = try fixture.writeImage(named: "swapped.jpg", pixelWidth: 160, pixelHeight: 90)
        let item = MediaItem(id: url, url: url, name: "swapped.jpg", kind: .image)

        let first = try #require(await service.preview(for: item))
        #expect(first.pixelWidth == 160)
        #expect(await service.preview(for: item) == first, "the warm cache serves the same value")

        await service.discardPreviews()

        try fixture.writeImage(named: "swapped.jpg", pixelWidth: 320, pixelHeight: 180)
        let second = try #require(await service.preview(for: item))
        #expect(second.pixelWidth == 320, "after the discard the same URL must re-extract — the cache was emptied (S9)")
        #expect(second != first)
    }
}

/// One-shot start gate: the task parks in `wait()` until `release()` —
/// making cancellation land before the parked call ever reaches the seam.
private actor StartGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var released = false

    var isArmed: Bool {
        continuation != nil
    }

    func wait() async {
        if released {
            return
        }
        await withCheckedContinuation { (pending: CheckedContinuation<Void, Never>) in
            continuation = pending
        }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
