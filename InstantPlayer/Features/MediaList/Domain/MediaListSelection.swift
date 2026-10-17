//
//  MediaListSelection.swift
//  InstantPlayer
//
//  MediaList Domain selection machine (E5-S1, design §3 — S6–S11, S18).
//

import Foundation

/// The one selection concept of product R28 (E5-S1 design §3): one ad-hoc,
/// ephemeral multi-selection over one ordered row array, with the two
/// standard macOS companion rows — the **anchor** (the ⇧-extend base) and
/// the **lead** (the keyboard-focus row that arrows move from and Enter
/// activates). A pure value: no SwiftUI, no AppKit, no I/O — the selection
/// is written nowhere and never persisted (S11, S14), and it is the single
/// seam E5-S2's operations will act on (design §6.2).
///
/// The machine owns no row storage: every row-dependent op takes the
/// ordered row identities as a parameter (the applied snapshot stays in
/// the view model, design §3.2). Membership checks are O(1) (`Set`); range
/// ops are O(range). Boundary behavior is Finder-standard: clamps at the
/// first and last row, never wraps — a repeat at the boundary is an
/// idempotent no-op (the D38 repeat-parity pattern).
nonisolated struct MediaListSelection: Equatable, Sendable {
    /// Arrow direction (S9): `.up` toward the first row, `.down` toward
    /// the last row.
    enum Direction: Equatable, Sendable {
        case up
        case down
    }

    /// The selected rows' identities (S6–S8).
    private(set) var selectedIDs: Set<MediaItem.ID> = []

    /// The ⇧-extend base (S8).
    private(set) var anchorID: MediaItem.ID?

    /// The keyboard-focus row — arrows move from it, Enter activates it
    /// (S9, S13).
    private(set) var leadID: MediaItem.ID?

    /// S6 — a single click: selection = {R}, anchor = lead = R. Never
    /// activates: this type has no activation API — activation is the view
    /// model's injected intent (design §4), so a selection change can
    /// structurally not switch views or start playback.
    mutating func select(_ id: MediaItem.ID) {
        selectedIDs = [id]
        anchorID = id
        leadID = id
    }

    /// S7 — ⌘-click: flip R's membership without discarding the rest;
    /// anchor = lead = R (Finder's anchor-on-⌘-click).
    mutating func toggle(_ id: MediaItem.ID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
        anchorID = id
        leadID = id
    }

    /// S8 — ⇧-click: selection = the contiguous anchor…target range in row
    /// order; lead = target; anchor unchanged. With no anchor (nothing
    /// selected yet) it behaves as `select`. The fail-safe when the anchor
    /// or the target is no longer a row (unreachable after `reset`, which
    /// runs at the one snapshot swap) is also `select(target)`.
    mutating func extend(to id: MediaItem.ID, over rows: [MediaItem.ID]) {
        guard let anchor = anchorID, let anchorIndex = rows.firstIndex(of: anchor),
              let targetIndex = rows.firstIndex(of: id)
        else {
            select(id)
            return
        }
        let range = min(anchorIndex, targetIndex) ... max(anchorIndex, targetIndex)
        selectedIDs = Set(rows[range])
        leadID = id
    }

    /// S9 — plain arrow: selection = {the row adjacent to the lead in that
    /// direction}; anchor = lead = that row. Clamps at the first/last row —
    /// never wraps; a repeat at the boundary is an idempotent no-op. With
    /// no lead yet, the Finder-standard entry applies: ↓ selects the first
    /// row, ↑ the last.
    mutating func move(_ direction: Direction, over rows: [MediaItem.ID]) {
        guard !rows.isEmpty else { return }
        guard let lead = leadID, let index = rows.firstIndex(of: lead) else {
            select(boundaryRow(for: direction, over: rows))
            return
        }
        let next = direction == .down ? index + 1 : index - 1
        guard rows.indices.contains(next) else { return }
        select(rows[next])
    }

    /// S9 — ⇧-arrow: the lead moves one row (clamped, never wrapping) and
    /// the selection becomes the anchor…lead range in row order; the
    /// anchor never moves. With no anchor/lead yet, the same
    /// Finder-standard entry as `move` applies.
    mutating func extend(_ direction: Direction, over rows: [MediaItem.ID]) {
        guard !rows.isEmpty else { return }
        guard let anchor = anchorID, let lead = leadID,
              let anchorIndex = rows.firstIndex(of: anchor),
              let leadIndex = rows.firstIndex(of: lead)
        else {
            select(boundaryRow(for: direction, over: rows))
            return
        }
        let next = direction == .down ? leadIndex + 1 : leadIndex - 1
        guard rows.indices.contains(next) else { return }
        leadID = rows[next]
        let range = min(anchorIndex, next) ... max(anchorIndex, next)
        selectedIDs = Set(rows[range])
    }

    /// S10 — a click on empty space: no rows selected, anchor and lead
    /// dropped.
    mutating func clear() {
        selectedIDs = []
        anchorID = nil
        leadID = nil
    }

    /// S18 — a new folder's snapshot replaces the rows wholesale: the
    /// selection is emptied so it can never outlive the rows it referred
    /// to. The one reset point is `MediaListViewModel.apply(collection:)`
    /// (design §3.2); nothing is written anywhere (S11, S14).
    mutating func reset() {
        selectedIDs = []
        anchorID = nil
        leadID = nil
    }

    /// The Finder-standard no-selection entry row for an arrow (see
    /// `move`): ↓ enters at the first row, ↑ at the last.
    private func boundaryRow(for direction: Direction, over rows: [MediaItem.ID]) -> MediaItem.ID {
        direction == .down ? rows[0] : rows[rows.count - 1]
    }
}
