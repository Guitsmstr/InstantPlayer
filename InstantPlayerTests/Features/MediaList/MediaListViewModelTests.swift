//
//  MediaListViewModelTests.swift
//  InstantPlayerTests
//
//  View-model, lifetime & list-parity suite (E5-S1, design §9.2, §9.4 —
//  S1, S2, S5, S12, S17, S18, S14).
//

import Foundation
@testable import InstantPlayer
import Testing

/// `@MainActor`: the view model is MainActor-isolated (house pattern).
/// Injected-seam doubles only (the E2-S3 house pattern) — no UI, no
/// window: the activation intent is recorded by a closure capture, and
/// the snapshots are synthetic `MediaCollection` values (URLs under the
/// temporary directory; no files are created or touched — the
/// display-only contract, S14, holds in tests too).
@MainActor
struct MediaListViewModelTests {
    /// One media item with a synthetic URL under `folder` (no file I/O).
    private static func makeItem(_ name: String, kind: MediaItemKind, in folder: URL) -> MediaItem {
        let fileURL = folder.appending(path: name)
        return MediaItem(id: fileURL, url: fileURL, name: name, kind: kind)
    }

    /// A synthetic snapshot: `itemNames` in the given order (the snapshot
    /// order); with `mixedKinds`, kinds alternate video/image.
    private static func makeCollection(
        _ name: String,
        itemNames: [String],
        capturedAt: Date,
        mixedKinds: Bool = false
    ) -> MediaCollection {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "e5-s1-vm-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
        let items = itemNames.enumerated().map { index, itemName in
            makeItem(
                itemName,
                kind: mixedKinds && index.isMultiple(of: 2) ? .video : .image,
                in: folder
            )
        }
        return MediaCollection(folderURL: folder, items: items, startIndex: 0, capturedAt: capturedAt)
    }

    // MARK: §9.2 — presentation toggle & lifetime (S5, S18, §5.3)

    /// S5, S18 — `togglePresentation()` flips the presented view only:
    /// the selection value is untouched (switching presentation and
    /// mutating selection are different methods — survival across
    /// switches is structural).
    @Test func toggleFlipsPresentationOnlyAndLeavesSelectionUntouched() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("t", itemNames: ["a.mp4", "b.mp4", "c.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        model.selectRow(collection.items[1].id)
        model.extendToRow(collection.items[2].id)
        let selectionBefore = model.selection

        model.togglePresentation()
        #expect(model.isListPresented)
        #expect(model.selection == selectionBefore)

        model.togglePresentation()
        #expect(!model.isListPresented)
        #expect(model.selection == selectionBefore)
    }

    /// S18 — `apply(collection:)` resets the selection exactly when a
    /// **new** snapshot value arrives (a different capture moment — the
    /// snapshot marker); re-applying the same snapshot value is a no-op.
    @Test func applyResetsOnlyOnANewSnapshotValue() {
        let model = MediaListViewModel()
        let first = Self.makeCollection(
            "f",
            itemNames: ["a.mp4", "b.mp4"],
            capturedAt: Date(timeIntervalSinceReferenceDate: 1)
        )
        model.apply(collection: first)
        model.selectRow(first.items[1].id)
        let selectionBefore = model.selection

        model.apply(collection: first)
        #expect(model.selection == selectionBefore)

        let second = Self.makeCollection(
            "s",
            itemNames: ["x.mp4", "y.mp4"],
            capturedAt: Date(timeIntervalSinceReferenceDate: 2)
        )
        model.apply(collection: second)
        #expect(model.selection.selectedIDs.isEmpty)
        #expect(model.selection.anchorID == nil)
        #expect(model.selection.leadID == nil)
        #expect(model.collection?.items == second.items)
    }

    /// S17 — the highlight projection is read-only: writing it (the
    /// feed's current item changing) can never count as or modify the
    /// selection — asserted as selection equality across highlight
    /// changes.
    @Test func highlightProjectionIsReadOnly() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("h", itemNames: ["a.mp4", "b.mp4", "c.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        model.selectRow(collection.items[1].id)
        let selectionBefore = model.selection

        model.highlightItemID = collection.items[0].id
        #expect(model.selection == selectionBefore)
        model.highlightItemID = collection.items[2].id
        #expect(model.selection == selectionBefore)
        model.highlightItemID = nil
        #expect(model.selection == selectionBefore)
    }

    // MARK: §9.2 — activation (S12, S13, §4's no-restart rule, §5.3)

    /// S12 — activation emits the right `MediaItem.ID` intent through the
    /// injected callback and never mutates the selection; both paths land
    /// on the feed (presentation flipped).
    @Test func activationEmitsTheRightIntentAndNeverMutatesSelection() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("a", itemNames: ["a.mp4", "b.mp4", "c.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        var intents: [MediaItem.ID] = []
        model.onActivate = { intents.append($0) }
        model.selectRow(collection.items[1].id)
        let selectionBefore = model.selection

        model.togglePresentation()
        #expect(model.isListPresented)

        model.activate(itemID: collection.items[2].id)
        #expect(intents == [collection.items[2].id])
        #expect(model.selection == selectionBefore)
        #expect(!model.isListPresented)

        model.activate(itemID: collection.items[0].id)
        #expect(intents == [collection.items[2].id, collection.items[0].id])
        #expect(model.selection == selectionBefore)
        #expect(!model.isListPresented)
    }

    /// §4 / §5.3 — activating the feed's current item (the highlight
    /// value) is a pure presentation flip: **no** intent is emitted, so
    /// no `moveTo` can be routed and playback can neither restart nor
    /// reposition; `startPlayback`/`restart()` are structurally
    /// unreachable (the model holds no session or feed reference, D7 —
    /// the injected double is the only outbound edge). Activating a
    /// different item does emit.
    @Test func activationOfTheAlreadyCurrentItemEmitsNothing() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("c", itemNames: ["a.mp4", "b.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        var intents: [MediaItem.ID] = []
        model.onActivate = { intents.append($0) }
        model.highlightItemID = collection.items[1].id

        model.togglePresentation()
        model.activate(itemID: collection.items[1].id)
        #expect(intents.isEmpty)
        #expect(!model.isListPresented)

        model.togglePresentation()
        model.activate(itemID: collection.items[0].id)
        #expect(intents == [collection.items[0].id])
    }

    /// S13 — Enter activates the lead row through the same path (the
    /// router's `activateLeadRow` dispatch, task 5).
    @Test func activateLeadRowEmitsTheLeadRow() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("l", itemNames: ["a.mp4", "b.mp4", "c.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        var intents: [MediaItem.ID] = []
        model.onActivate = { intents.append($0) }
        model.selectRow(collection.items[1].id)

        model.activateLeadRow()
        #expect(intents == [collection.items[1].id])
        #expect(!model.isListPresented)
    }

    /// §5.3 — toggling presentation never touches the playback session:
    /// the model's only outbound edge is the activation callback (not
    /// called by toggles — pinned); no `stop()`/`startPlayback`/
    /// `restart()` is even expressible here (D7).
    @Test func togglingPresentationNeverTouchesThePlaybackSession() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("p", itemNames: ["a.mp4"], capturedAt: Date())
        model.apply(collection: collection)
        var intents: [MediaItem.ID] = []
        model.onActivate = { intents.append($0) }

        model.togglePresentation()
        model.togglePresentation()
        model.presentFeed()
        #expect(intents.isEmpty)
    }

    // MARK: §9.4 — list parity (S1, S2; product R34–R36 parity)

    /// S1 — rows == `collection.items`: same count, same order, same
    /// names — the list renders the applied snapshot exactly.
    @Test func rowsEqualTheCollectionItems() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection("r", itemNames: ["z.mp4", "a.mov", "m.png"], capturedAt: Date())
        model.apply(collection: collection)
        #expect(model.collection?.items.count == collection.items.count)
        #expect(model.collection?.items == collection.items)
        #expect(model.collection?.items.map(\.name) == ["z.mp4", "a.mov", "m.png"])
    }

    /// S1 / product R34–R36 — a mixed media fixture (video + image
    /// interleaved) shows no non-media rows: rows == the collection, and
    /// the collection's contract (direct children, native media formats
    /// only — E2-S1/D20) is inherited by construction; there is no second
    /// scan to diverge.
    @Test func mixedMediaFixtureShowsNoNonMediaRows() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection(
            "m",
            itemNames: ["clip1.mp4", "shot1.png", "clip2.mov", "shot2.jpg"],
            capturedAt: Date(),
            mixedKinds: true
        )
        model.apply(collection: collection)
        let rows = model.collection?.items ?? []
        #expect(rows.count == 4)
        #expect(rows.allSatisfy { $0.kind == .video || $0.kind == .image })
        #expect(rows == collection.items)
    }

    /// S2 — honest snapshot: after `apply`, no row gains, drops, or
    /// reorders on its own — toggles, selection changes, highlight
    /// changes, and a same-snapshot re-apply all leave the rows
    /// identical.
    @Test func rowsNeverChangeAfterApply() {
        let model = MediaListViewModel()
        let collection = Self.makeCollection(
            "s",
            itemNames: ["a.mp4", "b.mp4", "c.mp4", "d.mp4"],
            capturedAt: Date()
        )
        model.apply(collection: collection)
        let rowsBefore = model.collection?.items

        model.togglePresentation()
        model.selectRow(collection.items[2].id)
        model.extendToRow(collection.items[0].id)
        model.highlightItemID = collection.items[1].id
        model.clearSelection()
        model.apply(collection: collection)
        #expect(model.collection?.items == rowsBefore)
    }
}
