//
//  FeedViewModel.swift
//  InstantPlayer
//
//  Feed Presentation view model — the house pattern (E1-S3, design §3.7 —
//  R3, R4; E2-S1, design §4 — S5–S7; E2-S2, design §5.1–§5.2, §5.5, §6.2,
//  §7 — S1, S4–S6, S9, S12, S13, S16).
//

import Foundation
import Observation

/// One feed item's display state (E2-S2 design §7): the cell is a pure
/// function of this state. `nil` (no entry) means not-yet-requested.
/// `.unavailable` is sticky for the session — no auto-retry (S12, S13).
nonisolated enum FeedItemDisplayState: Equatable {
    /// Requested, extraction in flight (design §8(1): unknown-media
    /// slowness degrades to `.loading`, never to a stall).
    case loading

    /// The display-ready preview (S3 — the poster).
    case preview(MediaPreview)

    /// The seam answered `nil` — vanished/unreadable (S12) or
    /// undecodable/mislabeled (S13). Sticky: never re-requested.
    case unavailable
}

/// The only presentation-state holder (D8): owns the `FeedState` machine,
/// routes the one entry action to the `MediaFolderRepository` seam, and —
/// since E2-S2 — owns the paging state: the current item over the open
/// collection's snapshot order (S1), the gesture guard (S4), the prefetch
/// window (§5.5), and the per-item display states (§7). `@MainActor
/// @Observable final class` per the house pattern (R3, R4).
///
/// Last-wins supersede (E2-S1 design §3.1, §4, §7.4): an entry action
/// arriving while a collection is in flight supersedes it — a generation
/// counter decides at completion, superseded results are dropped (no
/// queue, no re-scan of superseded work). E2-S2 reuses the same pattern
/// for preview results: a late result for a superseded collection never
/// paints (S9, design §6.2).
@MainActor
@Observable
final class FeedViewModel {
    private let mediaPlayerService: any MediaPlayerService
    private let mediaFolderRepository: any MediaFolderRepository
    private let mediaPreviewService: any MediaPreviewService

    /// The presentation state machine — starts in the welcome state (S5).
    private(set) var state: FeedState = .welcome

    /// Monotonic entry-action generation; only the newest action's result
    /// is applied (E2-S1 design §3.1: last one wins). Also the staleness
    /// guard for preview results (E2-S2 design §6.2 — a late result for
    /// the superseded collection never paints, S9).
    private var latestEntryGeneration = 0

    // MARK: Paging state (E2-S2 design §5.1–§5.2)

    /// The current item's index over `collection.items` — the snapshot
    /// order (S1). `nil` whenever no folder is open (S16: no paging state
    /// in welcome).
    private(set) var currentIndex: Int?

    /// The current item's identity — the two-way `scrollPosition(id:)`
    /// projection's read side (design §5.1: the binding is a projection of
    /// view-model state, never view state).
    private(set) var currentItemID: MediaItem.ID?

    /// Per-item display states keyed by item id (design §7).
    private(set) var displayStates: [MediaItem.ID: FeedItemDisplayState] = [:]

    /// The settled index a scroll gesture started from (design §5.2 step 1).
    private var gestureStartIndex: Int?

    /// In-flight preview requests keyed by item id (§5.5: dropped-edge
    /// work is cancelled when the window slides).
    private var previewTasks: [MediaItem.ID: Task<Void, Never>] = [:]

    init(
        mediaPlayerService: any MediaPlayerService,
        mediaFolderRepository: any MediaFolderRepository,
        mediaPreviewService: any MediaPreviewService
    ) {
        self.mediaPlayerService = mediaPlayerService
        self.mediaFolderRepository = mediaFolderRepository
        self.mediaPreviewService = mediaPreviewService
    }

    /// Routes one entry action (S1–S4) through the seam exactly once —
    /// one repository call per action (§7.4). Media arrives →
    /// `.folderOpen(collection)` positioned at the collection's starting
    /// item (S9, design §6.2). No media → `.welcome` (S5 at launch; S7
    /// mid-session — no folder stays open), with the display state
    /// discarded (S16). A superseded action's result is discarded (§3.1,
    /// §7.4).
    func handle(entryAction: EntryAction) async {
        latestEntryGeneration += 1
        let generation = latestEntryGeneration
        let collection = await mediaFolderRepository.prepareCollection(
            forEntryAt: entryAction
        )
        guard generation == latestEntryGeneration else { return }
        if let collection {
            state = .folderOpen(collection)
            await adopt(collection: collection)
        } else {
            state = .welcome
            await discardDisplayState()
        }
    }

    // MARK: Paging (S5, S6 — design §5.3)

    /// One item forward (S5), clamped at the last item — no wrap (S6).
    func pageForward() {
        guard let current = currentIndex else { return }
        setIndex(current + 1)
    }

    /// One item backward (S5), clamped at the first item — no wrap (S6).
    func pageBackward() {
        guard let current = currentIndex else { return }
        setIndex(current - 1)
    }

    /// The two-way `scrollPosition(id:)` projection's write side (design
    /// §5.1): the view's binding calls this with the item the scroll
    /// surface reports. Unknown/`nil` ids are ignored.
    func moveTo(itemID: MediaItem.ID?) {
        guard case let .folderOpen(collection) = state, let itemID,
              let index = collection.items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }
        setIndex(index)
    }

    // MARK: Gesture guard (S4 — design §5.2, pure logic)

    /// Scroll onset (scroll leaves rest): record the settled index as
    /// `gestureStart` (design §5.2 step 1). A new touch during
    /// deceleration starts a new gesture from the then-visible index —
    /// this method is called again and re-records (§5.2 step 3).
    func scrollGestureDidStart() {
        gestureStartIndex = currentIndex
    }

    /// Settle (scroll returns to rest): run the guard (design §5.2 step 2)
    /// — the final index must be exactly `gestureStart ± 1` in the net
    /// direction, clamped at the ends; any other landing is corrected by
    /// setting the current item (the two-way binding animates the scroll
    /// to that full page). A zero-net gesture does not page (S6).
    func scrollGestureDidSettle() {
        guard let start = gestureStartIndex else { return }
        gestureStartIndex = nil
        guard case let .folderOpen(collection) = state, let landing = currentIndex else { return }
        let corrected = Self.correctedTarget(
            forGestureStart: start,
            landing: landing,
            itemCount: collection.items.count
        )
        setIndex(corrected)
    }

    /// The gesture guard's correction as a pure function (design §5.2) —
    /// unit-testable without scroll hardware. Net direction from the index
    /// delta; the target is exactly one item from the start in that
    /// direction; clamped at both ends, no wrap (S6). A zero-net landing
    /// (snap-back, rubber-band at an end) stays at the start index (S4).
    nonisolated static func correctedTarget(forGestureStart start: Int, landing: Int, itemCount: Int) -> Int {
        let direction = landing > start ? 1 : (landing < start ? -1 : 0)
        guard itemCount > 0 else { return start }
        return min(max(start + direction, 0), itemCount - 1)
    }

    // MARK: State transitions (design §6.2)

    /// Replace-in-place reset (S9, design §6.2): the new collection starts
    /// at its `startIndex` (the inherited E2-S1 contract); the previous
    /// collection's position and display states are gone, and the preview
    /// seam is discarded before the new window is requested.
    private func adopt(collection: MediaCollection) async {
        cancelAllPreviewTasks()
        displayStates = [:]
        gestureStartIndex = nil
        currentIndex = collection.startIndex
        currentItemID = collection.items[collection.startIndex].id
        await mediaPreviewService.discardPreviews()
        refreshDisplayStates()
    }

    /// Welcome reset (S16, E2-S1 S7): no feed, no paging, no display
    /// state — and the preview seam's derived data is discarded (design §3:
    /// discard on returning to welcome).
    private func discardDisplayState() async {
        cancelAllPreviewTasks()
        displayStates = [:]
        gestureStartIndex = nil
        currentIndex = nil
        currentItemID = nil
        await mediaPreviewService.discardPreviews()
    }

    // MARK: Display states & prefetch window (design §5.5, §7)

    /// Moves the current index (both paging mechanisms share the clamp —
    /// S6) and slides the prefetch window.
    private func setIndex(_ index: Int) {
        guard case let .folderOpen(collection) = state, !collection.items.isEmpty else { return }
        let clamped = min(max(index, 0), collection.items.count - 1)
        guard clamped != currentIndex else { return }
        currentIndex = clamped
        currentItemID = collection.items[clamped].id
        refreshDisplayStates()
    }

    /// Prefetch window (design §5.5, RNF-02): request previews for the
    /// current item first, then its two immediate neighbors — nothing
    /// beyond the window is ever requested. Items dropped from the window
    /// lose their in-flight work (cancelled). Sticky states (`.preview` /
    /// `.unavailable`) are never re-requested (S12/S13: no retry); a
    /// `.loading` item that left and re-entered the window is re-requested.
    private func refreshDisplayStates() {
        guard case let .folderOpen(collection) = state, let current = currentIndex else { return }
        let items = collection.items

        var window = [items[current]]
        if current + 1 < items.count {
            window.append(items[current + 1])
        }
        if current - 1 >= 0 {
            window.append(items[current - 1])
        }
        let windowIDs = Set(window.map(\.id))

        for (id, task) in previewTasks where !windowIDs.contains(id) {
            task.cancel()
            previewTasks[id] = nil
            if displayStates[id] == .loading {
                displayStates[id] = nil
            }
        }

        for item in window {
            guard displayStates[item.id] == nil else { continue }
            displayStates[item.id] = .loading
            let generation = latestEntryGeneration
            previewTasks[item.id] = Task { [weak self] in
                guard let self else { return }
                let preview = await self.mediaPreviewService.preview(for: item)
                await self.apply(preview, toItemID: item.id, generation: generation)
            }
        }
    }

    /// Applies one preview answer (design §7): success → `.preview` (S3),
    /// `nil` → sticky `.unavailable` (S12, S13). Results for a superseded
    /// collection are dropped by the generation counter (S9 — a late
    /// result for the old collection never paints); results of cancelled
    /// (dropped-edge) requests are dropped too.
    private func apply(_ preview: MediaPreview?, toItemID id: MediaItem.ID, generation: Int) {
        guard generation == latestEntryGeneration else { return }
        guard !Task.isCancelled else { return }
        guard displayStates[id] == .loading else { return }
        displayStates[id] = preview.map { FeedItemDisplayState.preview($0) } ?? .unavailable
    }

    private func cancelAllPreviewTasks() {
        for task in previewTasks.values {
            task.cancel()
        }
        previewTasks = [:]
    }
}
