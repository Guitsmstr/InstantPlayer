//
//  MediaListViewModel.swift
//  InstantPlayer
//
//  MediaList Presentation view model (E5-S1, design §3.2, §3.3, §4, §6.1 —
//  S3–S13, S17, S18).
//

import Foundation
import Observation

/// The MediaList feature's one presentation-state holder (D8, house
/// pattern): owns the one `MediaListSelection` value (product R28 — the
/// seam E5-S2's operations will act on), the presented-view toggle, the
/// applied snapshot, and the activation intent. `@MainActor @Observable
/// final class` (R3, R4).
///
/// Lifetime & reset (S18, design §3.2): the selection survives every
/// list↔feed switch — switching presentation and mutating selection are
/// different methods, so survival is structural — and the machine's
/// `reset()` runs at exactly one point: `apply(collection:)` when a *new*
/// snapshot value arrives (a new entry action replaces the collection in
/// place, E2-S2 S9). Nothing about the selection, the highlight, or the
/// presentation is ever written anywhere (S11, S14).
///
/// Cross-feature discipline (D7, design §4): this model never references
/// `FeedViewModel` — the feed's current item arrives as the read-only
/// `highlightItemID` value, and row activation leaves through the
/// injected `onActivate` callback.
@MainActor
@Observable
final class MediaListViewModel {
    /// The applied snapshot (S1): the rows the list renders, in the
    /// collection's own order. `nil` until the first `apply`. Rows never
    /// change after build (S2) — the only mutation is the wholesale swap
    /// at the next new snapshot (design §6.3).
    private(set) var collection: MediaCollection?

    /// The one selection value (S6–S11) — the pure machine, held for the
    /// one open folder (design §3.2). Written only by the
    /// gesture-forwarding methods below.
    private(set) var selection = MediaListSelection()

    /// The presented view (S3–S5): `false` = the feed (the folder-open
    /// state's inherited landing view), `true` = the list. Flipped only
    /// by `togglePresentation()` and `presentFeed()`.
    private(set) var isListPresented = false

    /// The S17 position highlight: the feed's current item id, received
    /// as a read-only value from composition (RootView mirrors
    /// `FeedViewModel.currentItemID` — task 6's wiring). Deliberately a
    /// rendering input and *not* a part of `MediaListSelection`: the
    /// machine has no API that could accept it, so the highlight
    /// structurally cannot count as or modify the selection (S17, design
    /// §3.3). It is also the activation no-restart anchor (§4):
    /// activating the highlighted row — the feed's current item — is a
    /// pure presentation flip.
    var highlightItemID: MediaItem.ID?

    /// The activation intent (S12, S13, design §4): injected at
    /// composition — RootView binds it to the existing
    /// `FeedViewModel.moveTo(itemID:)`, the inherited positioning
    /// contract. Only a *different*-item activation is emitted: the
    /// already-current row never reaches the feed, so no
    /// `moveTo`/`startPlayback`/`restart()` can fire for it (§4's
    /// no-restart rule, §5.3).
    var onActivate: ((MediaItem.ID) -> Void)?

    /// The row identities of the applied snapshot, in snapshot order —
    /// the `rows` value every range/arrow op runs over. Rebuilt only when
    /// a new snapshot applies (S2: rows never change after build), so no
    /// per-gesture row-array work exists (design §7(3)).
    private var rowIDs: [MediaItem.ID] = []

    // MARK: Snapshot funnel (S18's single reset point — design §3.2)

    /// Applies one snapshot (S1). A *new* snapshot value — a different
    /// capture moment (`MediaCollection.capturedAt` is the snapshot
    /// marker, Core contract) — replaces the rows wholesale and resets
    /// the selection: the old rows are gone, so no selection may outlive
    /// them (S18). Re-applying the same snapshot value is a no-op:
    /// nothing resets.
    func apply(collection: MediaCollection) {
        if let applied = self.collection, applied.capturedAt == collection.capturedAt {
            return
        }
        self.collection = collection
        rowIDs = collection.items.map(\.id)
        selection.reset()
    }

    // MARK: Presentation toggle (S3–S5 — one toggle, two surfaces, §5.2)

    /// The one toggle (⌘L and the button are two surfaces over this):
    /// flips list↔feed. Presentation only — the selection value is not
    /// touched (S18 structural), and no playback state is reachable from
    /// here: the session lives below the switch, untouched (§5.3), and
    /// D7 keeps this model free of `FeedViewModel`.
    func togglePresentation() {
        isListPresented.toggle()
    }

    /// Lands on the feed without touching the selection (the S12/S13
    /// landing; §5.3 — a pure presentation flip, neither a teardown nor
    /// a revisit).
    func presentFeed() {
        isListPresented = false
    }

    // MARK: Selection gesture forwarding (S6–S10 — design §3.1)

    /// S6 — a single click: set that row, never activate.
    func selectRow(_ id: MediaItem.ID) {
        selection.select(id)
    }

    /// S7 — ⌘-click: membership flip, the rest preserved.
    func toggleRow(_ id: MediaItem.ID) {
        selection.toggle(id)
    }

    /// S8 — ⇧-click: extend from the anchor to that row.
    func extendToRow(_ id: MediaItem.ID) {
        selection.extend(to: id, over: rowIDs)
    }

    /// S9 — plain arrow (router-dispatched): move and collapse to the
    /// lead. Auto-repeat = repeated calls; the machine's boundary clamp
    /// keeps repeats idempotent (design §5.1).
    func moveSelection(_ direction: MediaListSelection.Direction) {
        selection.move(direction, over: rowIDs)
    }

    /// S9 — ⇧-arrow (router-dispatched): move the lead and extend from
    /// the anchor.
    func extendSelection(_ direction: MediaListSelection.Direction) {
        selection.extend(direction, over: rowIDs)
    }

    /// S10 — a click on empty space: clear.
    func clearSelection() {
        selection.clear()
    }

    // MARK: Activation (S12, S13 — design §4)

    /// Row activation — a navigation intent, never a selection action
    /// (the selection is untouched). Activating the feed's current item
    /// (the `highlightItemID` value) is a pure presentation flip: **no**
    /// intent is emitted, so playback can neither restart nor reposition
    /// (§4's no-restart rule, binding answer 1). A different item emits
    /// the intent through the injected callback; composition positions
    /// the feed on it. Both paths land on the feed.
    func activate(itemID: MediaItem.ID) {
        presentFeed()
        guard itemID != highlightItemID else { return }
        onActivate?(itemID)
    }

    /// S13 — Enter, the keyboard twin of double-click: activates the lead
    /// row (the machine's keyboard-focus row) through the same path.
    func activateLeadRow() {
        guard let lead = selection.leadID else { return }
        activate(itemID: lead)
    }
}
