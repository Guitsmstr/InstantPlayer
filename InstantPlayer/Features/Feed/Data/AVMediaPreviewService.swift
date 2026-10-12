//
//  AVMediaPreviewService.swift
//  InstantPlayer
//
//  Feed Data real conformance for the preview seam
//  (E2-S2, design §4, §5.4 — S2, S3, S12, S13).
//

import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// The real `MediaPreviewService`: first-frame extraction for videos
/// (`AVAssetImageGenerator`), downsampled thumbnails for images (ImageIO),
/// a bounded cache, and request coalescing — all behind the seam
/// (E2-S2 design §4, §5.4).
///
/// An `actor` on purpose (design §1.1 — the second D8 actor): the cache,
/// the in-flight registry, and the concurrency gate are mutable state
/// shared across isolation domains, and the actor's executor is the
/// boundary that keeps extraction, decode, downsample, and encode OFF the
/// main thread (design §8(2) — the project defaults to MainActor
/// isolation). The `@MainActor` view model receives only the finished
/// `MediaPreview`.
///
/// Security posture (design §9): reads happen only for items of the
/// currently open collection, inside the security-scoped session D19
/// already holds — no `start/stopAccessingSecurityScopedResource` here, no
/// session of its own, no new grants. File content is decode-only: never
/// executed, never parsed by name (D20 — the declared kind is trusted,
/// mislabeled content can only fail to decode → `nil` → S13). No logging
/// exists in this conformance (no paths, no names of user media).
actor AVMediaPreviewService: MediaPreviewService {
    // MARK: Tuning constants (design §5.4)

    /// Cache cost limit; an entry's cost is its `imageData` byte count.
    private static let cacheCostLimit = 64 * 1024 * 1024

    /// Cache entry limit — automatic eviction under pressure (skill §4:
    /// caches need an eviction policy).
    private static let cacheCountLimit = 32

    /// At most 2 concurrent extractions (design §5.4).
    private static let maxConcurrentExtractions = 2

    // MARK: State

    /// Bounded preview cache keyed by the item's resolved URL; entries are
    /// class boxes (`NSCache` requires object values — design §0.4). The
    /// cache is conformance-internal: the seam has no cache-control members
    /// beyond `discardPreviews()` (design §3).
    private let cache = NSCache<NSURL, PreviewBox>()

    /// The display bound in pixels (§4.2): 2× the screen's larger axis —
    /// captured at init, which the composition root runs on the main
    /// thread. Never full-resolution media is decoded (§5.4).
    private let maxPixelSize: Int

    /// In-flight extraction groups keyed by item URL (§5.4 coalescing:
    /// N concurrent calls for one item produce one extraction and one
    /// shared result).
    private var inFlight: [URL: InFlightExtraction] = [:]

    /// Concurrency-gate state: active extraction count plus the FIFO queue
    /// of extractions waiting for a slot.
    private var activeExtractions = 0
    private var pendingSlots: [PendingSlot] = []

    init() {
        maxPixelSize = Self.displayBoundPixels()
        cache.totalCostLimit = Self.cacheCostLimit
        cache.countLimit = Self.cacheCountLimit
    }

    // MARK: MediaPreviewService (frozen seam contract, design §3)

    func wiringProbe() async -> String {
        "AVMediaPreviewService"
    }

    func preview(for item: MediaItem) async -> MediaPreview? {
        // Cancellation-aware entry: a cancelled call never registers work
        // (design §3 — a cancelled task never completes its extraction).
        guard !Task.isCancelled else { return nil }

        let url = item.url
        if let cached = cache.object(forKey: url as NSURL) {
            return cached.preview
        }

        // Coalescing: join the item's in-flight group, or open the group
        // and schedule exactly one extraction. No await happens between the
        // group check and the waiter registration, so the actor cannot be
        // reentered in between.
        let groupID = UUID()
        if inFlight[url] == nil {
            let extraction = Task { await self.performExtraction(for: item, url: url, groupID: groupID) }
            inFlight[url] = InFlightExtraction(id: groupID, task: extraction, waiters: [:])
        }
        let waiterID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<MediaPreview?, Never>) in
                inFlight[url]?.waiters[waiterID] = continuation
            }
        } onCancel: {
            Task { await self.dropWaiter(waiterID, from: url) }
        }
    }

    /// Drops all cached previews and in-flight work (design §3, §5.4 — S9):
    /// called on replace-in-place and on returning to welcome, so derived
    /// data has exactly the open session's lifetime (design §8). Waiters of
    /// dropped groups are resumed with `nil` (dropped, never completed —
    /// callers treat a cancelled/dropped answer as no-result, not as the
    /// sticky S13 failure).
    func discardPreviews() async {
        cache.removeAllObjects()
        let dropped = inFlight
        inFlight = [:]
        for entry in dropped.values {
            entry.task.cancel()
            for continuation in entry.waiters.values {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: Extraction pipeline (design §4.2)

    /// Dispatch by the item's declared kind (D20's honest declared-type
    /// contract: content is never sniffed by name — it is decoded, or the
    /// decode fails → `nil`).
    private func extractPreview(from item: MediaItem) async -> MediaPreview? {
        switch item.kind {
        case .video:
            return await extractVideoPoster(from: item.url)
        case .image:
            return extractImagePreview(from: item.url)
        }
    }

    /// Video (S3): the first frame, honestly — frame requested at
    /// `CMTime.zero` with zero tolerance, preferred track transform applied,
    /// the frame bounded by the display bound (§5.4: full-resolution media
    /// is never decoded). The modern async API is used natively (no
    /// callback bridge) and is cancellation-aware. Exact-frame failure →
    /// `nil` (S13): no silent nearby-frame fallback, no generic icon.
    private func extractVideoPoster(from url: URL) async -> MediaPreview? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: CGFloat(maxPixelSize), height: CGFloat(maxPixelSize))
        guard let (image, _) = try? await generator.image(at: .zero) else { return nil }
        return Self.encodedPreview(from: image)
    }

    /// Image (S2): ImageIO downsamples during decode — thumbnail from the
    /// image always, bounded by the display bound (§4.2: never decode
    /// full-resolution media for display); the produced aspect is the
    /// source's.
    private func extractImagePreview(from url: URL) -> MediaPreview? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return Self.encodedPreview(from: thumbnail)
    }

    /// Both paths end in one ImageIO encode to display bytes + intrinsic
    /// size (design §4.2) — exactly the `MediaPreview` value shape.
    private static func encodedPreview(from image: CGImage) -> MediaPreview? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let compression: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImage(destination, image, compression as CFDictionary)
        guard CGImageDestinationFinalize(destination), let imageData = output as Data? else { return nil }
        return MediaPreview(imageData: imageData, pixelWidth: image.width, pixelHeight: image.height)
    }

    /// The display bound (§4.2): 2× the screen's larger axis in pixels
    /// (points × screen scale) — the viewport never exceeds the screen.
    /// Computed here, inside the Data conformance, so the seam signature
    /// stays frozen.
    private static func displayBoundPixels() -> Int {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let largerAxisPoints = screen.map { max($0.frame.width, $0.frame.height) } ?? 1920
        let scale = screen?.backingScaleFactor ?? 2
        return Int((largerAxisPoints * scale * 2).rounded(.up))
    }

    // MARK: Group lifecycle (coalescing + cancellation, design §5.4)

    /// The scheduled extraction (runs in the group's task on this actor's
    /// executor — design §8(2)): gate on the concurrency bound, extract,
    /// then complete the group (cache + resume waiters) — unless the group
    /// was dropped meanwhile, in which case the result is discarded, never
    /// completed.
    private func performExtraction(for item: MediaItem, url: URL, groupID: UUID) async {
        let granted = await acquireSlot()
        guard granted else {
            // Cancelled while queued — the group is already gone.
            completeExtraction(url: url, groupID: groupID, preview: nil, cancelled: true)
            return
        }
        let preview: MediaPreview?
        if Task.isCancelled {
            preview = nil
        } else {
            preview = await extractPreview(from: item)
        }
        releaseSlot()
        completeExtraction(url: url, groupID: groupID, preview: preview, cancelled: Task.isCancelled)
    }

    /// Group completion (on the actor): cache the result unless the group
    /// was cancelled/dropped, then resume every waiter exactly once.
    private func completeExtraction(url: URL, groupID: UUID, preview: MediaPreview?, cancelled: Bool) {
        guard let entry = inFlight.removeValue(forKey: url), entry.id == groupID else {
            return // the group was dropped (cancel/discard) — nothing to complete
        }
        if !cancelled, let preview {
            cache.setObject(PreviewBox(preview), forKey: url as NSURL, cost: preview.imageData.count)
        }
        for continuation in entry.waiters.values {
            continuation.resume(returning: cancelled ? nil : preview)
        }
    }

    /// Cancellation path: remove one waiter; when the last waiter leaves,
    /// the whole group is dropped and its extraction cancelled — superseded
    /// work is dropped, never completed (design §5.4).
    private func dropWaiter(_ waiterID: UUID, from url: URL) {
        guard var entry = inFlight[url],
              let continuation = entry.waiters.removeValue(forKey: waiterID)
        else {
            return // already completed — the waiter was resumed with the result
        }
        continuation.resume(returning: nil)
        if entry.waiters.isEmpty {
            inFlight.removeValue(forKey: url)
            entry.task.cancel()
        } else {
            inFlight[url] = entry
        }
    }

    // MARK: Concurrency gate (design §5.4: at most 2 concurrent extractions)

    /// Acquires an extraction slot; returns `false` when the calling task
    /// was cancelled while queued (it never held a slot).
    private func acquireSlot() async -> Bool {
        if Task.isCancelled {
            return false
        }
        if activeExtractions < Self.maxConcurrentExtractions {
            activeExtractions += 1
            return true
        }
        let slotID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                pendingSlots.append(PendingSlot(id: slotID, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelSlotWaiter(slotID) }
        }
    }

    /// Releases a held slot and wakes the FIFO head.
    private func releaseSlot() {
        activeExtractions -= 1
        grantSlots()
    }

    private func grantSlots() {
        while activeExtractions < Self.maxConcurrentExtractions, !pendingSlots.isEmpty {
            let next = pendingSlots.removeFirst()
            activeExtractions += 1
            next.continuation.resume(returning: true)
        }
    }

    private func cancelSlotWaiter(_ slotID: UUID) {
        guard let index = pendingSlots.firstIndex(where: { $0.id == slotID }) else { return }
        let waiter = pendingSlots.remove(at: index)
        waiter.continuation.resume(returning: false)
    }
}

/// One item's in-flight extraction group (§5.4): the scheduled work plus
/// every waiter's continuation.
private struct InFlightExtraction {
    let id: UUID
    let task: Task<Void, Never>
    var waiters: [UUID: CheckedContinuation<MediaPreview?, Never>]
}

/// A queued extraction waiting for a concurrency slot.
private struct PendingSlot {
    let id: UUID
    let continuation: CheckedContinuation<Bool, Never>
}

/// Object box for `NSCache` (requires object values — design §0.4).
///
/// `nonisolated` on purpose: NSCache releases (and evicts) entries from
/// whatever thread touches it, so the box must not carry an isolated
/// deinit — default-MainActor isolation would route cross-thread
/// deallocation through the deinit-on-executor machinery and corrupt the
/// heap (found by the E2-S2 task 6 suites at runtime). The box is an
/// immutable holder of a Sendable value; first runtime exercise is E2-S2
/// task 6 (coordinator ratification of this one-word fix requested).
private final nonisolated class PreviewBox {
    let preview: MediaPreview

    init(_ preview: MediaPreview) {
        self.preview = preview
    }
}
