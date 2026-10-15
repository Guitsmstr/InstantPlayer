//
//  FeedViewModel.swift
//  InstantPlayer
//
//  Feed Presentation view model — the house pattern (E1-S3, design §3.7 —
//  R3, R4; E2-S1, design §4 — S5–S7; E2-S2, design §5.1–§5.2, §5.5, §6.2,
//  §7 — S1, S4–S6, S9, S12, S13, S16; E2-S3, design §3, §6, §7 — S1–S11,
//  S14–S16; E3-S1, design §3, §4, §5, §7 — S1–S17; E3-S2, design §3, §5 —
//  the speed policy, S1–S18).
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

/// The overlay control bar's presentation value (E3-S1 design §7): a pure
/// value drilled to the current page; `nil` means structurally absent
/// (image pages, unavailable items, non-current pages, mid-paging — S4,
/// S12), while a non-`nil` model with `isVisible == false` is the
/// hidden-at-rest state that still drives the presentation semantics
/// (`opacity(0)` + `allowsHitTesting(false)` — the whole-page toggle stays
/// intact). Foundation-only (R10).
nonisolated struct PlaybackControlBarModel: Equatable {
    /// What the elapsed label shows (design §3): the view model's own
    /// displayed position — ticks and drag targets, never a player read
    /// (design §2's drift-proof arithmetic).
    let elapsed: TimeInterval

    /// The session's duration in seconds (design §3).
    let duration: TimeInterval

    /// The thumb's fraction along the track (`0...1`) — geometry stays a
    /// view concern; the view model reports the value (design §5).
    let scrubFraction: Double

    /// Visibility (S3): `true` while mouse activity keeps the bar up;
    /// `false` at rest. Keyboard seek never sets it (S3(b)).
    let isVisible: Bool

    /// The selected playback speed (E3-S2 design §5, S4): the badge's
    /// ≠ 1× rule and the menu's checkmark render from this value alone.
    /// It never affects the model's non-`nil` rule (the settled current
    /// video's live player page, unchanged from E3-S1).
    let speed: MediaPlaybackSpeed
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
/// (S14, S15). Since E3-S1 it is also the scrub & seek policy owner
/// (E3-S1 design §5): the drag state machine (S5–S8), the commit seeks
/// (S2, S9–S11), the seek guard matrix (S12), clamping + end handover
/// (S13, S14), the bar-visibility + idle policy (S3, S4), and the
/// time-display state (design §3). Since E3-S2 it is also the
/// playback-speed policy owner (E3-S2 design §3, §5): the app-session
/// selected speed (S8, S9 — nothing persisted; it resets only at
/// relaunch), the menu + keyboard entry points over one guard matrix
/// (S16), the pure ladder step with end clamps (S5–S7), the install
/// re-apply and start-at-speed ordering (S12), and preservation across
/// every seek and the loop (S13, S14). `@MainActor
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

    /// The app-session selected speed (E3-S2 design §3, S8, S9): written
    /// only by user input (menu selection, key step), read by every
    /// start, the badge, and the menu. Deliberately **not** cleared by
    /// `stopPlayback`, `adopt` (a newly opened folder), or the welcome
    /// transition — it carries across paging, revisits, and newly opened
    /// folders until changed (S8); it resets only at relaunch by object
    /// lifetime (RootView's one `FeedViewModel` per run, D18) and nothing
    /// is persisted (S9). The deliberate asymmetry with positions
    /// (E3-S1 S15) stands: position restarts, speed carries.
    private(set) var selectedSpeed: MediaPlaybackSpeed = .normal

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

    /// The poster-axis state parked under a live player surface (E2-S3
    /// design §4 implementation correction): when `.readyForDisplay`
    /// swaps the poster for the surface, what the poster axis held is
    /// parked here; stop-on-away restores it, so a departed item's cell
    /// never keeps a stopped player and a revisit always travels
    /// poster → `.player` (with `PlayerSurfaceView`'s per-session view
    /// identity). Entries live exactly as long as their `.player` state.
    private var parkedPosterStates: [MediaItem.ID: FeedItemDisplayState] = [:]

    // MARK: Scrub & seek state (E3-S1 design §2, §3, §4, §5)

    /// What the labels and thumb show (design §2): the view model keeps
    /// its own position and computes every commit target from it — never
    /// by reading the player's possibly-stale position. Fed by the clock
    /// consumer (`applyTick`), owned during a drag (`scrubChanged`),
    /// and set directly by every `.exact` commit.
    private(set) var displayedPosition: TimeInterval = 0

    /// The bar overlay's model (design §7): non-`nil` only for the
    /// settled current video's live player page; `isVisible == false` is
    /// the hidden-at-rest state. Recomputed by `refreshControlBar`.
    private(set) var controlBarModel: PlaybackControlBarModel?

    /// The chrome demand signal (E5-S1 design §5.2 — S4, D41): the
    /// floating view toggle's trigger. Raised by mouse movement over the
    /// settled current page of EITHER kind — video or image (§12(7)'s
    /// sanctioned Feed-side extension) — cleared by the shared 3 s idle
    /// hide and by the paths that kill the page context (paging start,
    /// session teardown), so it can never wedge. Deliberately independent
    /// of `controlBarModel` (D41): same trigger mechanism as the control
    /// bar, but no control-bar behavior or layout change.
    private(set) var isChromeDemanded = false

    /// The scrub drag flag (design §5): true from `beginScrub` until
    /// `scrubEnded` (or the session dying — `stopPlayback` resets it).
    /// Guards every tick and mid-drag keyboard seek (S12).
    private var isScrubbing = false

    /// The drag's play/pause memory (S8): recorded by `beginScrub` from
    /// `isPlaybackPaused` — which `beginScrub` deliberately does NOT
    /// touch (the pause is gesture-scoped) — and honored by `scrubEnded`:
    /// was-playing → `resume()`, was-paused → stay paused on the frozen
    /// frame.
    private var wasPlayingBeforeDrag = false

    /// The post-commit tick-suppression deadline (design §3): ticks are
    /// ignored until this instant — a stale tick right after an `.exact`
    /// seek would otherwise bounce the thumb backwards. Set by every
    /// `.exact` commit.
    private var exactSeekSuppressUntil: TimeInterval?

    /// The clock consumer (design §3): the installed session's
    /// `timeUpdates` loop, cancelled with the session (`stopPlayback`).
    private var playbackTimeTask: Task<Void, Never>?

    /// The idle-hide deadline (design §4, S3): armed by mouse activity,
    /// 3 s out, suspended for the whole scrub drag (S3(a)).
    private var idleDeadline: TimeInterval?

    /// The idle machinery (design §4): one cancellable generation-guarded
    /// `Task.sleep` — never a `Timer`, never a run-loop source — created
    /// only while a bar is visible, re-armed throttled to ≤ 4/s (§8(4)).
    private var idleTask: Task<Void, Never>?
    private var idleGeneration = 0
    private var lastIdleRearm: TimeInterval = 0

    /// The injected clock (design §4): the pure policy reads time only
    /// through this — tests drive the machinery deterministically with
    /// their own `now`.
    private let now: () -> TimeInterval

    init(
        mediaPlayerService: any MediaPlayerService,
        mediaFolderRepository: any MediaFolderRepository,
        mediaPreviewService: any MediaPreviewService,
        now: @escaping () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.mediaPlayerService = mediaPlayerService
        self.mediaFolderRepository = mediaFolderRepository
        self.mediaPreviewService = mediaPreviewService
        self.now = now
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
    /// surface reports. Unknown/`nil` ids are ignored. It is also the
    /// list's row-activation route (E5-S1 design §4/§6.1 — RootView binds
    /// `onActivate` here), so this is an arrive-on-item path: the landed
    /// item's auto-play runs through the settle-gated sync (S1; R11 —
    /// design §4's "ordinary arrive-on-item semantics apply unchanged",
    /// §5.3's inherited positioning/auto-play contract). An activation
    /// has no scroll gesture and no settle to follow, so its start lives
    /// here; mid-gesture binding writes stay start-free because
    /// `syncPlayback()` itself gates on being at rest (S2).
    ///
    /// `isExplicitActivation` marks the row-activation entrance (S12/S13
    /// — RootView's `onActivate`): explicit activation outranks stale
    /// in-flight scroll-gesture state (E5-S1 design §4, 2026-10-15), so
    /// that entrance cancels/clears any recorded gesture start *before*
    /// the arrive-on-item auto-play and the `moveTo` → `syncPlayback`
    /// path always runs at rest when entered from explicit activation.
    /// The clearing is scoped to this entrance only — the binding write
    /// side never clears (S2's settle-gating for ordinary scroll paging
    /// is untouched).
    func moveTo(itemID: MediaItem.ID?, isExplicitActivation: Bool = false) {
        guard case let .folderOpen(collection) = state, let itemID,
              let index = collection.items.firstIndex(where: { $0.id == itemID })
        else {
            return
        }
        if isExplicitActivation {
            gestureStartIndex = nil // activation cancels stale gesture state (E5-S1 design §4)
        }
        setIndex(index)
        syncPlayback()
    }

    // MARK: Gesture guard (S4 — design §5.2, pure logic)

    /// Scroll onset (scroll leaves rest): record the settled index as
    /// `gestureStart` (design §5.2 step 1). A new touch during
    /// deceleration starts a new gesture from the then-visible index —
    /// this method is called again and re-records (§5.2 step 3). A paging
    /// gesture in flight also drops the bar model to `nil` at once (S12's
    /// premise — design §4), suspends the idle machinery, and **clears
    /// the scrub state** — a paging gesture supersedes any in-flight drag
    /// (S12: its page lost eligibility), so the machine can never wedge
    /// with `isScrubbing` set.
    func scrollGestureDidStart() {
        gestureStartIndex = currentIndex
        isScrubbing = false
        wasPlayingBeforeDrag = false
        controlBarModel = nil
        isChromeDemanded = false // S12's premise extends to the floating toggle (E5-S1 §5.2)
        suspendIdlePolicy()
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
        // After the settle, the (possibly unchanged) current video's bar
        // model returns hidden-at-rest; a page-turned item stays `nil`
        // until its `.readyForDisplay` (design §7).
        refreshControlBar(visible: false)
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

    // MARK: Playback speed policy (E3-S2 design §3, §5 — S1–S18 policy)

    /// The menu route (E3-S2 S1): the drilled per-page selection (`FeedPageActions.speedSelected`,
    /// the item id captured at the drill site). Applies the selection
    /// through the shared core; a selection counts as pointer-independent
    /// activity — the bar refreshes visible and the 3 s idle countdown
    /// restarts (design §4, the `scrubEnded` precedent).
    func selectSpeed(_ speed: MediaPlaybackSpeed, itemID: MediaItem.ID) {
        applySpeedSelection(speed, itemID: itemID, countsAsActivity: true)
    }

    /// The `[` route (E3-S2 S5): one preset down the ladder — the pure
    /// `stepped` move handed to the shared core. No item id: the route is
    /// app-level and resolves to `currentItemID`, exactly like `stepSeek`.
    /// A keyboard step never shows the bar (approved F1).
    func stepSpeedDownByKeyboard() {
        guard let id = currentItemID else { return }
        applySpeedSelection(Self.stepped(selectedSpeed, up: false), itemID: id, countsAsActivity: false)
    }

    /// The `]` route (E3-S2 S5): one preset up — `stepSpeedDownByKeyboard`'s
    /// mirror. Auto-repeat arrives as repeated calls (S6) and clamps
    /// idempotently at the ladder ends (S7).
    func stepSpeedUpByKeyboard() {
        guard let id = currentItemID else { return }
        applySpeedSelection(Self.stepped(selectedSpeed, up: true), itemID: id, countsAsActivity: false)
    }

    /// One pure ladder move (E3-S2 S5–S7, design §5): walks
    /// `MediaPlaybackSpeed.allCases` (declaration order = ladder order) by
    /// one and **clamps at the ends** — 0.25× and 2× are ladder ends and
    /// the ladder never wraps. Pure and unit-testable without hardware.
    nonisolated static func stepped(_ speed: MediaPlaybackSpeed, up: Bool) -> MediaPlaybackSpeed {
        let ladder = MediaPlaybackSpeed.allCases
        guard let index = ladder.firstIndex(of: speed) else { return speed }
        let next = index + (up ? 1 : -1)
        guard ladder.indices.contains(next) else { return speed } // clamp (S7 — no wrap)
        return ladder[next]
    }

    /// The shared speed-selection core (E3-S2 design §5): run the guard
    /// matrix; then update the app-session selection; command the live
    /// handle when one exists (a still-starting video has none — the
    /// install re-apply governs that session, approved F2); refresh the
    /// bar model. A keyboard step leaves the bar exactly as found (F1 —
    /// chrome is demand-driven on mouse movement); a menu selection
    /// refreshes the bar visible and restarts the 3 s idle countdown
    /// (design §4). State neutrality (S10): never touches
    /// `isPlaybackPaused`, `displayedPosition`, or the index — a speed
    /// input can never toggle play/pause, move the playhead, or advance
    /// the feed. The seek paths never call this, so no scrub, track
    /// click, keyboard seek, or end handover can reset the speed (S13).
    private func applySpeedSelection(
        _ speed: MediaPlaybackSpeed,
        itemID: MediaItem.ID,
        countsAsActivity: Bool
    ) {
        guard speedGuard(itemID: itemID) else { return } // S16 — quiet consumed no-op
        selectedSpeed = speed
        playback?.setPlaybackSpeed(speed) // applied/remembered by the session (design §2)
        if countsAsActivity {
            restartIdleCountdown() // design §4: a selection re-arms the countdown
            refreshControlBar(visible: true)
        } else {
            refreshControlBar(visible: controlBarModel?.isVisible ?? false) // F1
        }
    }

    /// The speed guard matrix (E3-S2 S16, design §5's table) as one
    /// decision: speed is a property of the settled current video —
    /// non-current pages, pages while a paging gesture is in flight,
    /// image pages, and items in the neutral unavailable state (including
    /// sticky playback failure) consume the input quietly: no sound, no
    /// visual change, no error, never beep (S16, D28). Deliberately
    /// different from `seekGuard` where the approved spec says so: **no
    /// duration and no live handle are required** (speed is selection
    /// state, not a position operation) — a still-starting video accepts
    /// input as session state (approved F2; applied at install), and a
    /// mid-scrub drag is **remembered** (S10's approved composition note:
    /// the gesture-scoped pause makes it S11's paused path — unlike seek,
    /// which consumes mid-drag). The view is never consulted.
    private func speedGuard(itemID: MediaItem.ID) -> Bool {
        guard itemID == currentItemID else { return false } // non-current page (S16)
        guard gestureStartIndex == nil else { return false } // paging gesture in flight (S16)
        guard case let .folderOpen(collection) = state,
              let item = collection.items.first(where: { $0.id == itemID })
        else {
            return false // no open feed / unknown id (S16; welcome passes through at route level)
        }
        guard item.kind == .video else { return false } // image page — no playback semantics (S16)
        guard displayStates[itemID] != .unavailable else { return false } // neutral unavailable (S16)
        guard !playbackFailedItemIDs.contains(itemID) else { return false } // sticky playback failure (S16)
        return true
    }

    // MARK: Scrub & seek policy (E3-S1 design §4, §5 — S1–S15)

    /// Frozen constants (design §4, §5; spec S2, S3).
    private static let keyboardStepSeconds: TimeInterval = 5
    private static let controlBarIdleTimeout: TimeInterval = 3
    private static let exactSeekTickSuppression: TimeInterval = 0.25

    /// The re-arm throttle (§8(4)): pointer-rate `mouseMoved` extends the
    /// deadline every event (O(1)), but the idle task itself is recreated
    /// at most 4 times/s.
    private static let idleRearmInterval: TimeInterval = 0.25

    /// Drag start (S5, design §5 step 1): guard the matrix, record the
    /// play/pause memory, pause **gesture-scoped** — `isPlaybackPaused`
    /// itself is untouched, so the user's intent is preserved for S8 —
    /// and suspend the idle policy entirely (S3(a): `mouseDragged` is not
    /// `mouseMoved`, so without the suspend the bar would hide mid-drag).
    func beginScrub(itemID: MediaItem.ID) {
        guard !isScrubbing else { return } // already scrubbing
        guard let handle = seekGuard(itemID: itemID) else { return } // S12
        isScrubbing = true
        wasPlayingBeforeDrag = !isPlaybackPaused
        handle.pause() // gesture-scoped (S5)
        suspendIdlePolicy()
    }

    /// Drag movement (S5, S6 — design §5 step 2): the mapped target owns
    /// the display (labels/thumb track the pointer exactly) and issues a
    /// coalesced `.preview` seek (S6 — zero-tolerance since the converge
    /// amendment, so the displayed frame is the frame under the scrubber;
    /// the coalescing still bounds dispatch).
    func scrubChanged(itemID: MediaItem.ID, fraction: Double) {
        guard isScrubbing else { return } // design §5 step 2's guard
        guard let handle = seekGuard(itemID: itemID) else { return } // S12
        let target = Self.clampedTarget(fromFraction: fraction, duration: handle.duration)
        displayedPosition = target
        handle.seek(to: target, tolerance: .preview) // S6
        refreshControlBar(visible: true)
    }

    /// Drag release (S7, S8, S14 — design §5 step 3): the frame-exact
    /// `.exact` seek to the final target, the S8 restore
    /// (`wasPlayingBeforeDrag` → `resume()`, else stay paused on the
    /// frozen frame), the end handover when the clamped target is the
    /// duration (S14), and the idle countdown restart (S3(a)).
    func scrubEnded(itemID: MediaItem.ID, fraction: Double) {
        guard isScrubbing else { return } // design §5 step 3's guard
        guard let handle = seekGuard(itemID: itemID) else {
            // The drag's page lost eligibility mid-drag (a paging gesture
            // started, the session died, …): exit consistently — the
            // scrub state clears and the machine is never wedged (S12
            // hygiene). The bar/idle context is already consistent on
            // every such path (the failing guard's own handler cleared
            // it).
            isScrubbing = false
            wasPlayingBeforeDrag = false
            return
        }
        isScrubbing = false
        let target = Self.clampedTarget(fromFraction: fraction, duration: handle.duration)
        if target == handle.duration {
            endHandover(resumeAfter: wasPlayingBeforeDrag, handle: handle) // S14
        } else {
            displayedPosition = target
            handle.seek(to: target, tolerance: .exact) // S7 — frame-exact
            exactSeekSuppressUntil = now() + Self.exactSeekTickSuppression
            if wasPlayingBeforeDrag {
                handle.resume() // S8 restore
            } // else: stay paused on the frozen frame at the new position (S8)
        }
        wasPlayingBeforeDrag = false
        restartIdleCountdown() // S3(a): the deadline restarts after release
        refreshControlBar(visible: true)
    }

    /// The track-click seek (S11): `.exact` to the mapped target — never
    /// `pause()`/`resume()`; play/pause is left exactly as found (S10).
    func seekFromTrackClick(itemID: MediaItem.ID, fraction: Double) {
        guard let handle = seekGuard(itemID: itemID) else { return } // S12
        let target = Self.clampedTarget(fromFraction: fraction, duration: handle.duration)
        commitExactSeek(target, handle: handle)
    }

    /// The ← step (S2): −5 s from `displayedPosition` — the drift-proof
    /// arithmetic (two quick presses net exactly 10 s; design §2).
    /// Auto-repeat = repeated steps (S9). Consumed no-op on ineligible
    /// states (S12); never shows the bar (S3(b)).
    func seekBackwardByKeyboard() {
        stepSeek(by: -Self.keyboardStepSeconds)
    }

    /// The → step (S2): +5 s from `displayedPosition` — `stepSeek`'s
    /// mirror.
    func seekForwardByKeyboard() {
        stepSeek(by: Self.keyboardStepSeconds)
    }

    /// The demand signal's trigger (S3; E5-S1 design §5.2 — §12(7)'s
    /// sanctioned Feed edit): mouse movement over the settled current
    /// page raises the chrome demand — video or image alike — and arms
    /// the 3 s idle deadline. The bar half keeps its exact contract:
    /// only the settled current video's live player page shows the bar
    /// (S4, S12); movement on neighbors or welcome shows nothing,
    /// movement during a scrub drag changes nothing (the drag suspended
    /// the idle policy — S3(a)), and a paging gesture in flight drops
    /// both before this can run.
    func noteMouseMoved(itemID: MediaItem.ID) {
        guard !isScrubbing else { return } // S3(a): the drag owns the bar
        guard itemID == currentItemID, gestureStartIndex == nil else { return } // S4, S12
        // E5-S1 (design §5.2, §12(7)): the demand covers both page kinds
        // so the floating toggle mounts over video and image pages alike
        // (D41). The live-player gate below is untouched — no
        // control-bar behavior change.
        isChromeDemanded = true
        extendIdleCountdown()
        guard playbackItemID == itemID, isShowingPlayer(itemID) else { return } // live player page only
        refreshControlBar(visible: true)
    }

    // MARK: Scrub & seek internals (E3-S1 design §5 — one decision surface)

    /// The seek guard matrix (S12, design §5's table) as one decision:
    /// returns the live handle only when every row allows a seek — the
    /// settled current video (non-current and mid-gesture rejected), a
    /// live session (image pages, the neutral unavailable state including
    /// sticky playback failure, and still-starting videos have none), and
    /// a usable duration (the S13 clamp needs one). Guarded inputs do
    /// nothing quietly — never beep (D28).
    private func seekGuard(itemID: MediaItem.ID) -> (any MediaPlayback)? {
        guard itemID == currentItemID else { return nil } // non-current page (S12)
        guard gestureStartIndex == nil else { return nil } // paging gesture in flight (S12)
        guard let handle = playback, playbackItemID == itemID else { return nil } // no live session
        guard handle.duration > 0 else { return nil } // defensive: S13's clamp needs a duration
        return handle
    }

    /// The keyboard step (S2, S10): ±`delta` seconds from
    /// `displayedPosition`, clamped, `.exact` — leaving play/pause
    /// exactly as found (S10). Mid-drag keyboard seek is a consumed no-op
    /// (S12 — the release lands on the scrubber's point regardless, so a
    /// mid-drag key seek could never survive).
    private func stepSeek(by delta: TimeInterval) {
        guard !isScrubbing else { return } // mid-drag keyboard (S12)
        guard let id = currentItemID, let handle = seekGuard(itemID: id) else { return } // S12
        let target = Self.clampedTarget(fromSeconds: displayedPosition + delta, duration: handle.duration)
        commitExactSeek(target, handle: handle)
    }

    /// The commit path shared by the track click and the key steps (S2,
    /// S9–S11): an `.exact` seek to the (already clamped) target — with
    /// the end handover when the target is the duration (S14, the shared
    /// rule) and the 250 ms tick suppression (design §3: no thumb bounce
    /// from a stale tick). The bar's visibility is never changed here
    /// (S3(b): keyboard seek never shows the bar).
    private func commitExactSeek(_ target: TimeInterval, handle: any MediaPlayback) {
        if target == handle.duration {
            endHandover(resumeAfter: !isPlaybackPaused, handle: handle) // S14
            return
        }
        displayedPosition = target
        handle.seek(to: target, tolerance: .exact)
        exactSeekSuppressUntil = now() + Self.exactSeekTickSuppression
        refreshControlBar(visible: controlBarModel?.isVisible ?? false)
    }

    /// The end handover (S14, design §5): `target == duration` after
    /// clamping enters the D26 loop contract with this story's play-state
    /// rules — playing (or `wasPlayingBeforeDrag` on a release) →
    /// `handle.restart()` (seek-zero-and-play); paused →
    /// `handle.seek(to: 0, .exact)` and stay paused on the frozen frame
    /// at the beginning. **Both branches reset the displayed position to
    /// 0** — the labels/thumb report the restarted beginning immediately,
    /// not the stale end position until the next tick. The index is never
    /// touched (product R15 — no auto-advance by construction).
    private func endHandover(resumeAfter: Bool, handle: any MediaPlayback) {
        displayedPosition = 0
        if resumeAfter {
            handle.restart()
        } else {
            handle.seek(to: 0, tolerance: .exact)
            exactSeekSuppressUntil = now() + Self.exactSeekTickSuppression
        }
        refreshControlBar(visible: controlBarModel?.isVisible ?? false)
    }

    /// One clock tick (design §3): updates the displayed position —
    /// ignored during a scrub drag (the drag target owns the display) and
    /// suppressed for 250 ms after any `.exact` seek (a stale tick would
    /// bounce the thumb backwards). While the bar is **hidden** the tick
    /// costs the O(1) position store only (§8(3): zero consumer work —
    /// no property the feed body reads is mutated, so no view
    /// invalidates); the model is rebuilt from the current position when
    /// the bar becomes visible.
    private func applyTick(_ seconds: TimeInterval) {
        guard !isScrubbing else { return } // the drag owns the display
        if let until = exactSeekSuppressUntil, now() < until {
            return // 250 ms post-commit (design §3)
        }
        displayedPosition = seconds
        if controlBarModel?.isVisible == true {
            refreshControlBar(visible: true)
        }
    }

    /// Recomputes the bar model (design §7): non-`nil` only for the
    /// settled current video's live player page — no paging gesture, a
    /// live session for the current item, and the player surface (not
    /// poster/loading) actually showing; otherwise structurally absent.
    private func refreshControlBar(visible: Bool) {
        guard gestureStartIndex == nil, let id = currentItemID,
              let handle = playback, playbackItemID == id, isShowingPlayer(id)
        else {
            controlBarModel = nil
            return
        }
        let duration = handle.duration
        controlBarModel = PlaybackControlBarModel(
            elapsed: displayedPosition,
            duration: duration,
            scrubFraction: duration > 0 ? displayedPosition / duration : 0,
            isVisible: visible,
            speed: selectedSpeed
        )
    }

    /// The fraction → seconds mapping with the clamp (S13, design §5) as
    /// a pure function: `target = clamp(fraction × duration, 0,
    /// duration)` — which also doubles as input validation (no unbounded
    /// geometry ever reaches the player).
    nonisolated static func clampedTarget(fromFraction fraction: Double, duration: TimeInterval) -> TimeInterval {
        min(max(fraction * duration, 0), duration)
    }

    /// The seconds clamp (S13) — the key steps' arithmetic guard.
    nonisolated static func clampedTarget(fromSeconds seconds: TimeInterval, duration: TimeInterval) -> TimeInterval {
        min(max(seconds, 0), duration)
    }

    // MARK: Bar idle machinery (E3-S1 design §4 — S3, §8(4))

    /// Mouse-activity re-arm: the deadline extends every event (O(1));
    /// the task is recreated at most 4 times/s (§8(4)'s bound).
    private func extendIdleCountdown() {
        idleDeadline = now() + Self.controlBarIdleTimeout
        guard now() - lastIdleRearm >= Self.idleRearmInterval else { return }
        rearmIdleTask()
    }

    /// The forced re-arm (S3(a)): the scrub release restarts the countdown
    /// regardless of the throttle — a release is not pointer-rate input.
    private func restartIdleCountdown() {
        idleDeadline = now() + Self.controlBarIdleTimeout
        rearmIdleTask()
    }

    /// The one idle task (design §4): a generation-guarded `Task.sleep`
    /// to the current deadline — no `Timer`, no `CADisplayLink`, no
    /// run-loop source; it exists only while a bar is visible, and is
    /// owned and cancelled on every exit path (skill §4).
    private func rearmIdleTask() {
        lastIdleRearm = now()
        idleGeneration += 1
        let generation = idleGeneration
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            guard let self, let deadline = self.idleDeadline else { return }
            let remaining = deadline - self.now()
            guard remaining > 0 else {
                self.idleHide(generation: generation)
                return
            }
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self.idleHide(generation: generation)
        }
    }

    /// The pure hide decision, generation-guarded: a stale wake (newer
    /// activity, a drag, or a dead session bumped the generation) is
    /// dropped; a wake before the (re-extended) deadline re-arms for the
    /// remainder — the hide must happen even though the pointer never
    /// moves again.
    private func idleHide(generation: Int) {
        guard generation == idleGeneration, !isScrubbing else { return }
        guard let deadline = idleDeadline else { return }
        guard now() >= deadline else {
            rearmIdleTask()
            return
        }
        idleTask = nil
        isChromeDemanded = false // the shared idle hide clears the demand too (E5-S1 §5.2)
        refreshControlBar(visible: false)
    }

    /// Suspends the idle policy entirely (S3(a), design §4): the deadline
    /// is cleared and any in-flight sleep is made stale — used by the
    /// scrub drag and by every path that kills the bar's page context
    /// (paging start, page turns, session death).
    private func suspendIdlePolicy() {
        idleGeneration += 1
        idleTask?.cancel()
        idleTask = nil
        idleDeadline = nil
    }

    // MARK: Playback policy (E2-S3 design §3, §7)

    /// Settle-gated auto-play (S1, S2 — design §3): starts playback only
    /// when the feed is at rest — no paging in flight — for the current
    /// `.video` item without sticky playback failure. Call sites are the
    /// become-current paths: folder open at `startIndex` and
    /// replace-in-place (both via `adopt`, already at rest), paging
    /// settle (`scrollGestureDidSettle`), and `moveTo` (the at-rest
    /// arrival — list activation and the binding write side, E5-S1
    /// design §4/§5.3). A mid-gesture binding-write `moveTo` never
    /// reaches a start — the at-rest gate skips it, so the incoming item
    /// keeps its poster (S2); the explicit-activation entrance arrives
    /// at rest instead (stale gesture state cleared first, E5-S1 §4,
    /// 2026-10-15); images never start (S4); an already-live session for the
    /// current item is left alone (a settle that never left the item
    /// must not restart it — E5-S1 §4/§5.3's no-restart rule).
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
        // Start-at-speed (E3-S2 S12, design §3): the rate is chosen *with*
        // the play call — the selection captured here seeds the session's
        // first and only start call (`playImmediately(atRate:)`), so no 1×
        // beat exists to observe and the parameter adds zero work to the
        // asset-load path. A selection made while the asset is still
        // loading is covered by the install re-apply (approved F2).
        let startSpeed = selectedSpeed
        playbackStartTask = Task { [weak self] in
            let handle = await self?.mediaPlayerService.startPlayback(for: item, at: startSpeed)
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
        displayedPosition = 0 // a fresh session starts at the beginning (S15 — nothing carried)
        // Install re-apply (E3-S2 design §3, S12; approved F2): one
        // synchronous statement before the event/clock loops attach — a
        // selection made while this session's asset was still loading
        // governs the session it landed on (S8: the selection applies to
        // every subsequently viewed video).
        handle.setPlaybackSpeed(selectedSpeed)
        playbackEventTask = Task { [weak self] in
            for await event in handle.events {
                guard let self else { return }
                self.applyPlayback(event, from: handle, toItemID: item.id, generation: generation)
            }
        }
        // The clock consumer (design §3): ticks feed the displayed
        // position (drag- and suppression-aware — `applyTick`) until the
        // stream finishes on `stop()` or the task is cancelled with the
        // session.
        playbackTimeTask = Task { [weak self] in
            for await tick in handle.timeUpdates {
                guard let self else { return }
                self.applyTick(tick)
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
        playbackTimeTask?.cancel()
        playbackTimeTask = nil
        playback?.stop()
        playback = nil
        playbackItemID = nil
        isPlaybackPaused = false
        // E3-S1 (S15 — nothing carried; design §7): the drag machine, the
        // displayed position, the tick suppression, and the bar die with
        // the session — a drag on a stopping session cannot survive it,
        // and the bar is structurally absent without a live player page.
        // The selected speed deliberately does NOT die with the session
        // (E3-S2 S8: app-session state — it carries until changed).
        isScrubbing = false
        wasPlayingBeforeDrag = false
        displayedPosition = 0
        exactSeekSuppressUntil = nil
        controlBarModel = nil
        isChromeDemanded = false // the demand never outlives its page context (E5-S1 §5.2)
        suspendIdlePolicy()
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
        case .readyForDisplay where !isShowingPlayer(id):
            // The poster→player swap (design §4): the poster-axis state
            // parks first — it is the revert target when the item is
            // departed (stop-on-away hygiene). Never parks a `.player`
            // state (a repeated `.readyForDisplay` is idempotent).
            parkedPosterStates[id] = displayStates[id] ?? .loading
            displayStates[id] = .player(handle)
            // The current video's page is now live: its bar model exists
            // hidden-at-rest (design §7 — chrome is demand-driven; mouse
            // movement shows it, S3).
            refreshControlBar(visible: false)
        case .readyForDisplay:
            break // the surface is already installed
        case .reachedEnd:
            handle.restart()
        case .failed:
            stopPlayback()
            playbackFailedItemIDs.insert(id)
            parkedPosterStates[id] = nil // playback failure is sticky — the poster revert is moot
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
        parkedPosterStates = [:]
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
        parkedPosterStates = [:]
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
        let departedItemID = currentItemID
        stopPlayback()
        currentIndex = clamped
        currentItemID = collection.items[clamped].id
        revertDepartedDisplayState(departedItemID)
        refreshDisplayStates()
    }

    /// Stop-on-away display hygiene (E2-S3 design §4 implementation
    /// correction): the departed item is off-screen — its `.player` state
    /// reverts to the parked poster state (`.preview`/`.loading`/
    /// `.unavailable`, whatever the poster axis held), so the cell never
    /// keeps a stopped player surface and a revisit always travels
    /// poster → `.player` instead of `.player(old) → .player(new)` — the
    /// transition SwiftUI cannot rebuild (the review defect: revisiting
    /// showed no picture). Paired with `PlayerSurfaceView`'s per-session
    /// view identity.
    private func revertDepartedDisplayState(_ itemID: MediaItem.ID?) {
        guard let itemID, isShowingPlayer(itemID) else { return }
        displayStates[itemID] = parkedPosterStates.removeValue(forKey: itemID) ?? .loading
    }

    /// True while the item's cell is showing a live player surface.
    private func isShowingPlayer(_ itemID: MediaItem.ID) -> Bool {
        if case .player = displayStates[itemID] {
            return true
        }
        return false
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
    /// (dropped-edge) requests are dropped too. A late answer for an item
    /// that is already live-playing must not paint over the surface — it
    /// parks as the stop-on-away revert target instead (design §4
    /// implementation correction).
    private func apply(_ preview: MediaPreview?, toItemID id: MediaItem.ID, generation: Int) {
        guard generation == latestEntryGeneration else { return }
        guard !Task.isCancelled else { return }
        if isShowingPlayer(id) {
            parkedPosterStates[id] = preview.map { FeedItemDisplayState.preview($0) } ?? .unavailable
            return
        }
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
