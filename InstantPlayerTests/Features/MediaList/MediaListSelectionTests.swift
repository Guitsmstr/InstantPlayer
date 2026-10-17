//
//  MediaListSelectionTests.swift
//  InstantPlayerTests
//
//  Selection-machine suite over generated row arrays (E5-S1, design
//  §9.1 — S6–S11, S18).
//

import Foundation
@testable import InstantPlayer
import Testing

/// The Finder-grade selection mechanics as pure value tests (design
/// §9.1): no view hierarchy, no mouse hardware — the machine takes the
/// ordered row identities and the gesture op, and the assertions pin the
/// resulting value exactly. Row arrays are generated synthetic URLs (no
/// files are created or touched — the machine never performs I/O, S14).
struct MediaListSelectionTests {
    /// A generated ordered row array — distinct synthetic URLs in a
    /// stable index order (the snapshot order the machine runs over).
    private static func rows(_ count: Int) -> [MediaItem.ID] {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "e5-s1-rows-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (0 ..< count).map { folder.appending(path: "row-\($0)") }
    }

    // MARK: Single click (S6)

    /// S6 — a single click sets that row as the whole selection with
    /// anchor = lead = it. "Never activates" is structural: the type has
    /// no activation API at all — the only observable after `select` is
    /// selection state, so a selection change cannot switch views or
    /// touch playback (design §3, §4).
    @Test func singleClickSetsAndNeverActivates() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        #expect(selection.selectedIDs == [rows[1]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[1])
    }

    /// S6 — "sets" replaces: a click on another row discards the previous
    /// selection entirely.
    @Test func singleClickReplacesPreviousSelection() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[0])
        selection.select(rows[3])
        #expect(selection.selectedIDs == [rows[3]])
        #expect(selection.anchorID == rows[3])
        #expect(selection.leadID == rows[3])
    }

    // MARK: ⌘-click (S7)

    /// S7 — ⌘-click flips the clicked row's membership and preserves the
    /// rest; anchor = lead = the clicked row.
    @Test func commandClickTogglesMembershipPreservingTheRest() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.toggle(rows[3])
        #expect(selection.selectedIDs == [rows[1], rows[3]])
        #expect(selection.anchorID == rows[3])
        #expect(selection.leadID == rows[3])
        selection.toggle(rows[1])
        #expect(selection.selectedIDs == [rows[3]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[1])
    }

    /// S7 — ⌘-click on the only selected row deselects it while the
    /// anchor/lead stay on it (Finder keeps the focus row even when
    /// deselected).
    @Test func commandClickCanDeselectTheOnlySelectedRow() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[2])
        selection.toggle(rows[2])
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.anchorID == rows[2])
        #expect(selection.leadID == rows[2])
    }

    // MARK: ⇧-click (S8)

    /// S8 — ⇧-click builds the contiguous anchor…target range in row
    /// order (both directions), keeps the anchor, and moves the lead.
    @Test func shiftClickBuildsAnchorTargetRangeAndKeepsTheAnchor() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.extend(to: rows[4], over: rows)
        #expect(selection.selectedIDs == [rows[1], rows[2], rows[3], rows[4]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[4])
        selection.extend(to: rows[0], over: rows)
        #expect(selection.selectedIDs == [rows[0], rows[1]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[0])
    }

    /// S8 — with no anchor (nothing selected yet) ⇧-click behaves as a
    /// plain select.
    @Test func shiftClickWithoutAnchorBehavesAsSelect() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.extend(to: rows[2], over: rows)
        #expect(selection.selectedIDs == [rows[2]])
        #expect(selection.anchorID == rows[2])
        #expect(selection.leadID == rows[2])
    }

    // MARK: Arrows (S9)

    /// S9 — plain arrows move the selection one row and collapse to the
    /// lead: selection = {adjacent row}, anchor = lead = that row.
    @Test func arrowsMoveAndCollapseToTheLead() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.move(.down, over: rows)
        #expect(selection.selectedIDs == [rows[2]])
        #expect(selection.anchorID == rows[2])
        #expect(selection.leadID == rows[2])
        selection.move(.up, over: rows)
        #expect(selection.selectedIDs == [rows[1]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[1])
    }

    /// S9 — ⇧-arrows move the lead one row (clamped) and select the
    /// anchor…lead range; the anchor never moves.
    @Test func shiftArrowsExtendFromTheAnchor() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.extend(.down, over: rows)
        #expect(selection.selectedIDs == [rows[1], rows[2]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[2])
        selection.extend(.down, over: rows)
        #expect(selection.selectedIDs == [rows[1], rows[2], rows[3]])
        #expect(selection.leadID == rows[3])
        selection.extend(.up, over: rows)
        #expect(selection.selectedIDs == [rows[1], rows[2]])
        #expect(selection.anchorID == rows[1])
        #expect(selection.leadID == rows[2])
    }

    /// S9 — arrows clamp at the first and last row and never wrap.
    @Test func arrowsClampAtBothEndsAndNeverWrap() {
        let rows = Self.rows(3)
        var selection = MediaListSelection()
        selection.select(rows[2])
        selection.move(.down, over: rows)
        #expect(selection.selectedIDs == [rows[2]])
        #expect(selection.leadID == rows[2])
        selection.select(rows[0])
        selection.move(.up, over: rows)
        #expect(selection.selectedIDs == [rows[0]])
        #expect(selection.leadID == rows[0])
    }

    /// S9 — a repeat at the boundary is an idempotent no-op (the D38
    /// repeat-parity pattern): held arrows at either end leave the value
    /// untouched, so auto-repeat builds no backlog (design §7(3)).
    @Test func boundaryRepeatsAreIdempotentNoOps() {
        let rows = Self.rows(3)
        var selection = MediaListSelection()
        selection.select(rows[2])
        let atEnd = selection
        for _ in 0 ..< 10 {
            selection.move(.down, over: rows)
            #expect(selection == atEnd)
            selection.extend(.down, over: rows)
            #expect(selection == atEnd)
        }
        selection.select(rows[0])
        let atStart = selection
        for _ in 0 ..< 10 {
            selection.move(.up, over: rows)
            #expect(selection == atStart)
            selection.extend(.up, over: rows)
            #expect(selection == atStart)
        }
    }

    /// S9 — with no selection yet, an arrow uses the Finder-standard
    /// entry: ↓ selects the first row, ↑ the last (the standard macOS
    /// behavior the spec adopts wholesale; pinned so the entry stays
    /// deliberate).
    @Test func arrowWithNoSelectionUsesFinderEntryRow() {
        let rows = Self.rows(3)
        var selection = MediaListSelection()
        selection.move(.down, over: rows)
        #expect(selection.selectedIDs == [rows[0]])
        var upward = MediaListSelection()
        upward.move(.up, over: rows)
        #expect(upward.selectedIDs == [rows[2]])
    }

    // MARK: Empty click (S10) & reset (S18)

    /// S10 — a click on empty space clears: no rows selected, anchor and
    /// lead dropped.
    @Test func emptyClickClears() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.extend(.down, over: rows)
        selection.clear()
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.anchorID == nil)
        #expect(selection.leadID == nil)
    }

    /// S18 — `reset()` empties everything: a new folder's snapshot
    /// replaces the rows wholesale, so no selection may outlive the rows
    /// it referred to.
    @Test func resetEmptiesEverything() {
        let rows = Self.rows(5)
        var selection = MediaListSelection()
        selection.select(rows[1])
        selection.extend(.down, over: rows)
        selection.reset()
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.anchorID == nil)
        #expect(selection.leadID == nil)
        #expect(selection == MediaListSelection())
    }
}
