//
//  FeedViewModel.swift
//  InstantPlayer
//
//  Feed Presentation view model — the house pattern (E1-S3, design §3.7 —
//  R3, R4; E2-S1, design §4 — S5–S7; E2-S2, design §5.1–§5.2, §5.5, §6.2,
//  §7 — S1, S4–S6, S9, S12, S13, S16; E2-S3, design §3, §6, §7 — S1–S11,
//  S14–S16).
//

import Foundation
import Observation

/// One feed item's display state (E2-S2 design §7; E2-S3 design §4): the
/// cell is a pure function of this state. `nil` (no entry) means
/// not-yet-requested. `.unavailable` is sticky for the session — no
/// auto-retry (S12, S13).
///
/// `Equatable` is hand-written (E2-S3 design §4): `.player` cases compare
/// session handles by identity (`===`) — a handle is immutable per
/// session, so identity is its value; the other cases keep structural
/// equality so the wrap memo and `onChange` behavior carry over.
nonisolated enum FeedItemDisplayState: Equatable {
    /// Requested, extraction in flight (design §8(1): unknown-media
    /// slowness degrades to `.loading`, never to a stall).
    case loading

    /// The display-ready preview (S3 — the poster). For the current video
    /// it stays on screen until the session emits `.readyForDisplay` —
    /// the poster IS frame 0 (E2-S3 design §4).
    case preview(MediaPreview)

    /// The current video's live playback surface (E2-S3 design §4) —
    /// reached only on `.readyForDisplay`; the paused presentation is the
    /// layer's frozen frame, nothing else (S8).
    case player(MediaPlayback)

    /// The seam answered `nil` — vanished/unreadable (S12) or
    /// undecodable/mislabeled (S13). Sticky: never re-requested. E2-S3
    /// extends it to playback failure (S14, S15) on the same terms.
    case unavailable

    static func == (lhs: FeedItemDisplayState, rhs: FeedItemDisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case let (.preview(lhsPreview), .preview(rhsPreview)):
            return lhsPreview == rhsPreview
        case let (.player(lhsHandle), .player(rhsHandle)):
            return lhsHandle === rhsHandle
        case (.unavailable, .unavailable):
            return true
        default:
            return false
        }
    }
}

/// The only presentation-state holder (D8): owns the `FeedState` machine,
/// routes the one entry action to the `MediaFolderRepository` seam, and —
/// since E2-S2 — owns the paging state: the current item over the open
/// collection's snapshot order (S1), the gesture guard (S4), the prefetch
/// window (§5.5), and the per-item display states (§7). Since E2-S3 it is
/// also the playback policy owner (design §3, §6): the settle-gated
/// auto-play (S1, S2), the play/pause toggles and their guard matrix
/// (S5–S7), the stop-on-away/restart-on-revisit lifecycle (S9, S10), the
/// loop policy (S11), and the per-axis playback-failure stickiness
/// (S14, S15). `@MainActor
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

    // MARK: Playback state (E2-S3 design §3, §6, §7)

    /// The current playback session handle — the ONLY holder (D8): `nil`
    /// whenever no video is current or starting. Stopped synchronously on
    /// every current-item change (S9 — no audio past the page turn,
    /// design §8(2)); a session's lifetime is exactly its item's
    /// currency, plus the in-flight start (design §3).
    private var playback: (any MediaPlayback)?

    /// The item id the session was started for — the currency anchor a
    /// late `startPlayback` result must match before installing (design
    /// §3 brace 3, with the generation counter below).
    private var playbackItemID: MediaItem.ID?

    /// Pause tracking (design §6 guard matrix): the frozen handle has no
    /// state-query member (design §2's minimal session) — the view model,
    /// the policy owner, tracks it. A fresh session auto-plays (S1), so
    /// it installs unpaused; the frozen-frame pause (S8) changes nothing
    /// visible but this flag.
    private var isPlaybackPaused = false

    /// The in-flight `startPlayback` (S1): the settle path is synchronous,
    /// so the async seam call rides this task; cancelled by supersession
    /// and by every stop (a superseded start never installs — design §3
    /// brace 3).
    private var playbackStartTask: Task<Void, Never>?

    /// The installed session's event-consumption loop (design §3): ends
    /// when the stream finishes (`stop()`) or the task is cancelled.
    private var playbackEventTask: Task<Void, Never>?

    /// Per-axis stickiness (design §7): once *playback* fails for an item
    /// — `nil` from the seam or a `.failed` event — it is never
    /// re-attempted this session. Poster failure is a separate axis and
    /// never blocks an attempt (honest recovery: playback succeeding
    /// shows `.player`). A fresh entry action resets everything (E2-S2's
    /// "way out").
    private var playbackFailedItemIDs: Set<MediaItem.ID> = []

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
        finalizeArrowPage()
    }

    /// One item backward (S5), clamped at the first item — no wrap (S6).
    func pageBackward() {
        guard let current = currentIndex else { return }
        setIndex(current - 1)
        finalizeArrowPage()
    }

    /// The arrow page is its own settle — design §3's sanctioned fallback,
    /// taken after functional review: programmatic page animations (the
    /// arrow-key `scrollPosition` moves) emit no `onScrollPhaseChange`
    /// idle on this OS build, so the scroll surface's settle signal never
    /// fires for arrows. The arrow path is deterministic — its clamped
    /// landing is known synchronously — so the settle-equivalent runs
    /// here, exactly what `scrollGestureDidSettle()` does for gestures
    /// minus the correction (the arrow landing is already exactly one
    /// clamped item): in-flight gesture state is cleared (arrows win over
    /// any in-flight gesture — their landing is deterministic; the
    /// gesture path's phase events stay untouched) and the at-rest
    /// playback sync runs (S1, S2). This also makes the state impossible
    /// to wedge: a direct index-set path always ends at rest, so the
    /// mid-gesture toggle guard (S7) is released and spacebar/click work
    /// immediately after arrow paging.
    private func finalizeArrowPage() {
        gestureStartIndex = nil
        syncPlayback()
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
    /// to that full page). A zero-net gesture does not page (S6). The
    /// settle is also THE auto-play trigger for paging (E2-S3 S1, S2 —
    /// design §3): the single settle signal for scroll gestures and
    /// arrow-key page animations alike.
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
        syncPlayback()
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

    // MARK: Playback toggles (E2-S3 design §6 — S5–S7, the guard matrix)

    /// The spacebar route (S5): toggles the settled current video — pause
    /// when playing, resume when paused. The whole guard matrix is decided
    /// here; the view is never consulted (design §6): paging in flight →
    /// no-op (S7); no live session — an image page (S4), a sticky-failed
    /// item (design §7), welcome, or a still-starting video — → no-op
    /// (S7). Consumed-and-quiet by construction; repeated presses toggle
    /// once per press (space auto-repeat is consumed upstream, task 4).
    func togglePlayback() {
        guard gestureStartIndex == nil else { return } // paging in flight (S7)
        guard let handle = playback else { return } // no live session (S4, S7, design §7)
        if isPlaybackPaused {
            handle.resume()
            isPlaybackPaused = false
        } else {
            handle.pause()
            isPlaybackPaused = true
        }
    }

    /// The tap route (S6): a single click anywhere on a page toggles only
    /// when the clicked page IS the settled current item — clicks on
    /// non-current pages are no-ops (S7). The cell never sees the item;
    /// only the id travels (E2-S2 S14's structural absence holds). The
    /// remaining guards are `togglePlayback()`'s, shared.
    func togglePlaybackFromTap(itemID: MediaItem.ID) {
        guard itemID == currentItemID else { return } // non-current page (S7)
        togglePlayback()
    }

    // MARK: Playback policy (E2-S3 design §3, §7)

    /// Settle-gated auto-play (S1, S2 — design §3): starts playback only
    /// when the feed is at rest — no paging in flight — for the current
    /// `.video` item without sticky playback failure. Call sites are the
    /// become-current paths: folder open at `startIndex` and
    /// replace-in-place (both via `adopt`, already at rest) and paging
    /// settle (`scrollGestureDidSettle`). A mid-gesture `moveTo` never
    /// reaches a start — index changes mid-gesture don't call this, so
    /// the incoming item keeps its poster (S2); images never start (S4);
    /// an already-live session for the current item is left alone (a
    /// settle that never left the item must not restart it).
    private func syncPlayback() {
        guard case let .folderOpen(collection) = state else { return }
        guard gestureStartIndex == nil, let index = currentIndex else { return } // at rest (S2)
        let item = collection.items[index]
        guard item.kind == .video else { return } // images have no playback (S4)
        guard !playbackFailedItemIDs.contains(item.id) else { return } // per-axis stickiness (design §7)
        guard playbackItemID != item.id else { return } // already live — no restart
        // A new session supersedes any live one — exactly one live player
        // (design §3); the seam tears its own previous session down too.
        stopPlayback()
        playbackItemID = item.id
        let generation = latestEntryGeneration
        playbackStartTask = Task { [weak self] in
            let handle = await self?.mediaPlayerService.startPlayback(for: item)
            guard !Task.isCancelled else {
                handle?.stop() // superseded mid-start: never install, never leak
                return
            }
            guard let self else {
                handle?.stop()
                return
            }
            self.install(handle, for: item, generation: generation)
        }
    }

    /// Installs (or drops) a finished `startPlayback` result (design §3
    /// brace 3): a superseded generation or a no-longer-current item is
    /// stopped and dropped — a stale session never installs. `nil` is the
    /// unified failure answer (S14, S15): the item's display state becomes
    /// the sticky neutral `.unavailable` and the item is never
    /// re-attempted this session (per-axis stickiness, design §7).
    private func install(_ handle: (any MediaPlayback)?, for item: MediaItem, generation: Int) {
        guard generation == latestEntryGeneration, playbackItemID == item.id else {
            handle?.stop()
            return
        }
        guard let handle else {
            playbackFailedItemIDs.insert(item.id)
            displayStates[item.id] = .unavailable
            return
        }
        playback = handle
        isPlaybackPaused = false // fresh sessions auto-play (S1)
        playbackEventTask = Task { [weak self] in
            for await event in handle.events {
                guard let self else { return }
                self.applyPlayback(event, from: handle, toItemID: item.id, generation: generation)
            }
        }
    }

    /// Stops and drops the session — synchronously, in the caller's
    /// main-actor turn (S9: no audio past the page turn, design §8(2)).
    /// Also cancels the in-flight start and the event loop: late events
    /// never paint or sound (design §3 — brace 1 is the finished stream
    /// and cancelled loop; braces 2 and 3 remain in `applyPlayback`/`install`).
    private func stopPlayback() {
        playbackStartTask?.cancel()
        playbackStartTask = nil
        playbackEventTask?.cancel()
        playbackEventTask = nil
        playback?.stop()
        playback = nil
        playbackItemID = nil
        isPlaybackPaused = false
    }

    /// Applies one playback event (design §3, §5, §7) behind the
    /// late-event braces: the generation counter (a superseded
    /// collection's session never acts) and handle identity (a stopped or
    /// superseded handle can never match the installed one).
    ///
    /// `.readyForDisplay` swaps the poster for the player surface
    /// (design §4 — the poster stays until this swap and is frame 0);
    /// `.reachedEnd` restarts the SAME session with the index untouched
    /// (S11 — never auto-advance, design §5); `.failed` stops the session
    /// and shows the sticky `.unavailable` (S14, design §7).
    private func applyPlayback(
        _ event: MediaPlaybackEvent,
        from handle: any MediaPlayback,
        toItemID id: MediaItem.ID,
        generation: Int
    ) {
        guard generation == latestEntryGeneration else { return } // brace 3
        guard playback === handle else { return } // brace 2 — identity
        switch event {
        case .readyForDisplay:
            displayStates[id] = .player(handle)
        case .reachedEnd:
            handle.restart()
        case .failed:
            stopPlayback()
            playbackFailedItemIDs.insert(id)
            displayStates[id] = .unavailable
        }
    }

    // MARK: State transitions (design §6.2)

    /// Replace-in-place reset (S9, design §6.2): the new collection starts
    /// at its `startIndex` (the inherited E2-S1 contract); the previous
    /// collection's position and display states are gone, and the preview
    /// seam is discarded before the new window is requested. The playback
    /// session of the replaced collection is stopped with it (E2-S3
    /// design §3), and the new collection auto-plays at its `startIndex`
    /// (S1 — a become-current path, design §3).
    private func adopt(collection: MediaCollection) async {
        cancelAllPreviewTasks()
        stopPlayback()
        playbackFailedItemIDs = [] // a fresh entry action resets everything (design §7)
        displayStates = [:]
        gestureStartIndex = nil
        currentIndex = collection.startIndex
        currentItemID = collection.items[collection.startIndex].id
        await mediaPreviewService.discardPreviews()
        refreshDisplayStates()
        syncPlayback()
    }

    /// Welcome reset (S16, E2-S1 S7): no feed, no paging, no display
    /// state — and the preview seam's derived data is discarded (design §3:
    /// discard on returning to welcome). The playback session is stopped
    /// and dropped alongside the display-state reset (E2-S3 design §3).
    private func discardDisplayState() async {
        cancelAllPreviewTasks()
        stopPlayback()
        playbackFailedItemIDs = []
        displayStates = [:]
        gestureStartIndex = nil
        currentIndex = nil
        currentItemID = nil
        await mediaPreviewService.discardPreviews()
    }

    // MARK: Display states & prefetch window (design §5.5, §7)

    /// Moves the current index (both paging mechanisms share the clamp —
    /// S6) and slides the prefetch window. A change stops the current
    /// playback session synchronously, in this same main-actor turn
    /// (E2-S3 S9 — nothing keeps playing off-screen; no audio past the
    /// page turn, design §8(2)). Starting is settle-gated (S2): this
    /// method never starts playback.
    private func setIndex(_ index: Int) {
        guard case let .folderOpen(collection) = state, !collection.items.isEmpty else { return }
        let clamped = min(max(index, 0), collection.items.count - 1)
        guard clamped != currentIndex else { return }
        stopPlayback()
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
