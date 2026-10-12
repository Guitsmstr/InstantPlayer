//
//  FeedViewModelTests.swift
//  InstantPlayerTests
//
//  Welcome-state machine through an injected seam double (E2-S1, design
//  §9.2 — S5–S7, §7.4 no-redundant-work).
//

import Foundation
@testable import InstantPlayer
import Testing

/// `@MainActor`: the view model is MainActor-isolated.
@MainActor
struct FeedViewModelTests {
    private static func uniqueFolder(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "vm-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private static func makeCollection(
        folderURL: URL,
        itemCount: Int = 1,
        startIndex: Int = 0
    ) -> MediaCollection {
        MediaCollection(
            folderURL: folderURL,
            items: (0 ..< itemCount).map { index in
                let fileURL = folderURL.appending(path: "item-\(index).mp4")
                return MediaItem(id: fileURL, url: fileURL, name: "item-\(index).mp4", kind: .video)
            },
            startIndex: startIndex,
            capturedAt: Date()
        )
    }

    /// S5 — the view model starts in the welcome state.
    @Test func startsInWelcome() {
        let viewModel = FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: ScriptedMediaFolderRepository(results: []),
            mediaPreviewService: StubMediaPreviewService()
        )
        guard case .welcome = viewModel.state else {
            Issue.record("S5: the view model must start in .welcome")
            return
        }
    }

    /// S6 — a media entry opens the folder carrying the seam's startIndex.
    @Test func mediaEntryOpensFolderWithSeamStartIndex() async {
        let folder = Self.uniqueFolder("open")
        let collection = Self.makeCollection(folderURL: folder, itemCount: 3, startIndex: 2)
        let seam = ScriptedMediaFolderRepository(results: [collection])
        let viewModel = FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: seam,
            mediaPreviewService: StubMediaPreviewService()
        )

        await viewModel.handle(entryAction: EntryAction(enteredURL: folder))
        guard case let .folderOpen(opened) = viewModel.state else {
            Issue.record("S6: a media entry must leave welcome and open the folder")
            return
        }
        #expect(opened.folderURL == folder)
        #expect(opened.startIndex == 2)
    }

    /// S7 — a no-media entry while a folder is open drops back to welcome,
    /// leaving no folder open.
    @Test func noMediaEntryWhileOpenDropsToWelcome() async {
        let folderA = Self.uniqueFolder("a")
        let media = Self.makeCollection(folderURL: folderA)
        let seam = ScriptedMediaFolderRepository(results: [media, nil])
        let viewModel = FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: seam,
            mediaPreviewService: StubMediaPreviewService()
        )

        await viewModel.handle(entryAction: EntryAction(enteredURL: folderA))
        guard case .folderOpen = viewModel.state else {
            Issue.record("test setup: the first action must open the folder")
            return
        }

        await viewModel.handle(entryAction: EntryAction(enteredURL: Self.uniqueFolder("b")))
        guard case .welcome = viewModel.state else {
            Issue.record("S7: a no-media mid-session entry must drop back to welcome")
            return
        }
    }

    /// S5 — a no-media entry while welcome stays welcome (no folder opens).
    @Test func noMediaEntryWhileWelcomeStaysWelcome() async {
        let seam = ScriptedMediaFolderRepository(results: [nil])
        let viewModel = FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: seam,
            mediaPreviewService: StubMediaPreviewService()
        )

        await viewModel.handle(entryAction: EntryAction(enteredURL: Self.uniqueFolder("x")))
        guard case .welcome = viewModel.state else {
            Issue.record("S5: a no-media entry while welcome must stay welcome")
            return
        }
    }

    /// §3.1/§7.4 — rapid successive actions: last wins, and the seam is
    /// called exactly once per action (no superseded re-scan, no queue).
    /// Deterministic: action A hangs INSIDE the seam on a continuation
    /// gate until B has fully applied; the double echoes each action's own
    /// URL, so the surviving action's collection is identifiable.
    @Test func rapidActionsLastWinsOneSeamCallPerAction() async {
        let folderA = Self.uniqueFolder("rapid-a")
        let folderB = Self.uniqueFolder("rapid-b")
        let seam = ScriptedMediaFolderRepository(echoingEnteredURL: true, holdingFirstCall: true)
        let viewModel = FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: seam,
            mediaPreviewService: StubMediaPreviewService()
        )

        // Action A begins and suspends inside the seam (gate armed).
        let inFlight = Task { await viewModel.handle(entryAction: EntryAction(enteredURL: folderA)) }
        var spins = 0
        while await seam.callCount == 0 {
            await Task.yield()
            spins += 1
            if spins >= 10000 {
                Issue.record("the first action never reached the seam")
                await seam.releaseFirstCall()
                await inFlight.value
                return
            }
        }
        #expect(await seam.isHoldingFirstCall, "the first action must hang inside the seam")

        // Action B supersedes A and applies while A is still in flight.
        await viewModel.handle(entryAction: EntryAction(enteredURL: folderB))

        // Release A; its superseded result must be dropped (last wins).
        await seam.releaseFirstCall()
        await inFlight.value

        guard case let .folderOpen(opened) = viewModel.state else {
            Issue.record("the surviving action must open its folder; state = \(viewModel.state)")
            return
        }
        #expect(opened.folderURL == folderB, "the last action's folder must win, got \(opened.folderURL)")
        let finalCallCount = await seam.callCount
        #expect(finalCallCount == 2, "exactly one seam call per action, got \(finalCallCount)")
    }

    // MARK: Paging & display state machine (E2-S2 design §10.1 — S1, S4–S6, S9, S12, S13, S16)

    /// Fixed preview value the display-state rows compare against — the
    /// canonical PNG bytes with an arbitrary known intrinsic size.
    private static let knownPreview = MediaPreview(
        imageData: Data(MediaFixture.png1x1),
        pixelWidth: 4,
        pixelHeight: 3
    )

    private static func makeViewModel(
        repository: MediaFolderRepository,
        previews: MediaPreviewService
    ) -> FeedViewModel {
        FeedViewModel(
            mediaPlayerService: StubMediaPlayerService(),
            mediaFolderRepository: repository,
            mediaPreviewService: previews
        )
    }

    /// The common arrange step of the §10.1 rows: script `collection` into
    /// the repository, build the view model, perform the entry action.
    private static func openCollection(
        _ collection: MediaCollection,
        repository: ScriptedMediaFolderRepository,
        previews: MediaPreviewService
    ) async -> FeedViewModel {
        let viewModel = makeViewModel(repository: repository, previews: previews)
        await viewModel.handle(entryAction: EntryAction(enteredURL: collection.folderURL))
        return viewModel
    }

    /// Deterministic wait (the E2-S1 supersede pattern): spin the main
    /// actor until `condition` holds or the spin budget runs out.
    private static func waitFor(
        _ condition: @MainActor () async -> Bool,
        spins limit: Int = 10000,
        _ message: String
    ) async -> Bool {
        var spins = 0
        while await condition() == false {
            await Task.yield()
            spins += 1
            if spins >= limit {
                Issue.record("\(message)")
                return false
            }
        }
        return true
    }

    /// §10.1 row 1 — folder open → the current item is the collection's
    /// `startIndex` (S1; S9's inherited contract).
    @Test func folderOpenPositionsCurrentItemAtCollectionStartIndex() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("position"), itemCount: 5, startIndex: 3)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        #expect(viewModel.currentIndex == 3)
        #expect(viewModel.currentItemID == collection.items[3].id)
    }

    /// §10.1 row 2 — `pageForward`/`pageBackward` move exactly one item in
    /// the snapshot order (S5); the state change is observable.
    @Test func pageForwardAndBackwardMoveExactlyOneItem() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("paging"), itemCount: 5, startIndex: 2)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.pageForward()
        #expect(viewModel.currentIndex == 3, "one item forward (S5)")
        #expect(viewModel.currentItemID == collection.items[3].id)

        viewModel.pageBackward()
        #expect(viewModel.currentIndex == 2, "one item back (S5)")

        viewModel.pageBackward()
        #expect(viewModel.currentIndex == 1)
        #expect(viewModel.currentItemID == collection.items[1].id)
    }

    /// §10.1 row 3 — clamping at both ends is a no-op, no wrap (S6, the
    /// arrow mechanism); paging still works after clamping.
    @Test func clampingAtBothEndsHasNoWrap() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("clamp"), itemCount: 3, startIndex: 0)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.pageBackward()
        viewModel.pageBackward()
        #expect(viewModel.currentIndex == 0, "backward at the first item must be a no-op — no wrap (S6)")
        #expect(viewModel.currentItemID == collection.items[0].id)

        viewModel.pageForward()
        viewModel.pageForward()
        viewModel.pageForward()
        viewModel.pageForward()
        #expect(viewModel.currentIndex == 2, "forward at the last item must be a no-op — no wrap (S6)")
        #expect(viewModel.currentItemID == collection.items[2].id)

        viewModel.pageBackward()
        #expect(viewModel.currentIndex == 1, "the view model must remain pageable after clamping")
    }

    /// §10.1 row 4 — the gesture guard's pure correction table (S4, S6;
    /// design §5.2): net direction from the index delta, exactly one item
    /// in that direction, clamped at both ends, zero-net stays put.
    @Test func gestureGuardCorrectionTable() {
        struct Row {
            let start: Int
            let landing: Int
            let itemCount: Int
            let expected: Int
        }
        let rows = [
            Row(start: 2, landing: 5, itemCount: 6, expected: 3), // multi-page forward → start + 1
            Row(start: 2, landing: 0, itemCount: 6, expected: 1), // multi-page backward → start − 1
            Row(start: 2, landing: 2, itemCount: 6, expected: 2), // snap-back → gestureStart + 0
            Row(start: 0, landing: 0, itemCount: 6, expected: 0), // zero-net at the first end → no page
            Row(start: 5, landing: 5, itemCount: 6, expected: 5), // zero-net at the last end → no page
            Row(start: 4, landing: 9, itemCount: 5, expected: 4), // forward past the last end → clamped
            Row(start: 0, landing: -2, itemCount: 5, expected: 0), // backward past the first end → clamped
            Row(start: 0, landing: 3, itemCount: 1, expected: 0), // single-item collection → clamps to itself
        ]
        for row in rows {
            let corrected = FeedViewModel.correctedTarget(
                forGestureStart: row.start,
                landing: row.landing,
                itemCount: row.itemCount
            )
            #expect(
                corrected == row.expected,
                "start \(row.start), landing \(row.landing), count \(row.itemCount) → got \(corrected)"
            )
        }
    }

    /// §10.1 row 4 (state machine) — a multi-page forward momentum landing
    /// is corrected to `gestureStart + 1` at settle (S4).
    @Test func gestureGuardCorrectsMultiPageForwardLanding() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("guard-fwd"), itemCount: 5, startIndex: 1)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: collection.items[4].id) // momentum landed three pages ahead
        #expect(viewModel.currentIndex == 4, "the scroll surface's landing is applied first")
        viewModel.scrollGestureDidSettle()

        #expect(viewModel.currentIndex == 2, "the guard corrects the landing to gestureStart + 1 (S4)")
        #expect(viewModel.currentItemID == collection.items[2].id)
    }

    /// §10.1 row 4 (state machine) — a multi-page backward landing is
    /// corrected to `gestureStart − 1` at settle (S4).
    @Test func gestureGuardCorrectsMultiPageBackwardLanding() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("guard-back"), itemCount: 5, startIndex: 3)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: collection.items[0].id) // momentum landed three pages back
        #expect(viewModel.currentIndex == 0)
        viewModel.scrollGestureDidSettle()

        #expect(viewModel.currentIndex == 2, "the guard corrects the landing to gestureStart − 1 (S4)")
        #expect(viewModel.currentItemID == collection.items[2].id)
    }

    /// §10.1 row 4 (state machine) — a snap-back lands on the start page:
    /// zero net direction, the guard keeps the start item.
    @Test func gestureGuardSnapBackStaysAtStartPage() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("guard-snap"), itemCount: 5, startIndex: 2)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: collection.items[2].id) // scrolled away, settled back at the start
        viewModel.scrollGestureDidSettle()

        #expect(viewModel.currentIndex == 2, "a snap-back must not page (S4)")
    }

    /// §10.1 row 4 (state machine) — a zero-net gesture at either end
    /// (rubber-band) does not page (S6).
    @Test func zeroNetGestureAtAnEndDoesNotPage() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("guard-end"), itemCount: 3, startIndex: 0)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: StubMediaPreviewService()
        )

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: collection.items[0].id) // rubber-band at the first item
        viewModel.scrollGestureDidSettle()
        #expect(viewModel.currentIndex == 0, "zero-net at the first end must not page (S6)")

        viewModel.pageForward()
        viewModel.pageForward()
        #expect(viewModel.currentIndex == 2)

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: collection.items[2].id) // rubber-band at the last item
        viewModel.scrollGestureDidSettle()
        #expect(viewModel.currentIndex == 2, "zero-net at the last end must not page (S6)")
    }

    /// §10.1 row 5 — replace-in-place (S9): the new collection starts at
    /// its own `startIndex`, the previous collection's display state is
    /// gone, and `discardPreviews()` ran once per open.
    @Test func replaceInPlaceResetsToNewStartIndexAndDiscardsPreviews() async {
        let collectionA = Self.makeCollection(folderURL: Self.uniqueFolder("replace-a"), itemCount: 3, startIndex: 0)
        let collectionB = Self.makeCollection(folderURL: Self.uniqueFolder("replace-b"), itemCount: 4, startIndex: 1)
        let service = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collectionA,
            repository: ScriptedMediaFolderRepository(results: [collectionA, collectionB]),
            previews: service
        )
        let arranged = await Self.waitFor(
            { await service.totalCalls >= 2 },
            "the first window's requests must arrive"
        )
        guard arranged else { return }
        viewModel.pageForward()
        viewModel.pageForward()
        #expect(viewModel.currentIndex == 2)

        await viewModel.handle(entryAction: EntryAction(enteredURL: collectionB.folderURL))

        guard case let .folderOpen(opened) = viewModel.state else {
            Issue.record("the second entry must open collection B")
            return
        }
        #expect(opened.folderURL == collectionB.folderURL)
        #expect(viewModel.currentIndex == 1, "replace-in-place lands on the new collection's startIndex (S9)")
        #expect(viewModel.currentItemID == collectionB.items[1].id)
        #expect(
            viewModel.displayStates[collectionA.items[0].id] == nil,
            "the previous collection's display state must be gone"
        )
        let discards = await service.discardCount
        #expect(discards == 2, "discardPreviews must run once per collection open, got \(discards)")
    }

    /// §10.1 row 5 — a late preview result for the superseded collection
    /// never paints (S9): the same item id is re-opened, the stale answer
    /// is released first, and it must be dropped (generation counter and
    /// task cancellation), while the fresh answer paints.
    @Test func latePreviewResultForSupersededCollectionNeverPaints() async {
        let folder = Self.uniqueFolder("stale")
        let itemURL = folder.appending(path: "same.mp4")
        let item = MediaItem(id: itemURL, url: itemURL, name: "same.mp4", kind: .video)
        let collectionA = MediaCollection(folderURL: folder, items: [item], startIndex: 0, capturedAt: Date())
        let collectionB = MediaCollection(folderURL: folder, items: [item], startIndex: 0, capturedAt: Date())
        let stalePreview = MediaPreview(imageData: Data(MediaFixture.png1x1), pixelWidth: 1, pixelHeight: 1)
        let freshPreview = MediaPreview(imageData: Data(MediaFixture.png1x1), pixelWidth: 9, pixelHeight: 7)
        let service = GatedPreviewService()
        let viewModel = await Self.openCollection(
            collectionA,
            repository: ScriptedMediaFolderRepository(results: [collectionA, collectionB]),
            previews: service
        )
        let parked = await Self.waitFor(
            { await service.callCount == 1 },
            "the first collection's request must park on the gate"
        )
        guard parked else { return }

        // Replace-in-place while the first request is still parked.
        await viewModel.handle(entryAction: EntryAction(enteredURL: folder))
        let requeued = await Self.waitFor(
            { await service.callCount == 2 },
            "the replacement collection must re-request the item"
        )
        guard requeued else { return }

        // Release the stale answer: it must never paint.
        await service.releaseFirst(for: itemURL, with: stalePreview)
        #expect(
            viewModel.displayStates[item.id] == .loading,
            "the stale answer must be dropped (S9) — the item stays in .loading"
        )

        // Release the fresh answer: it paints.
        await service.releaseFirst(for: itemURL, with: freshPreview)
        let applied = await Self.waitFor(
            { viewModel.displayStates[item.id] != .loading },
            "the fresh answer must arrive"
        )
        guard applied else { return }
        #expect(viewModel.displayStates[item.id] == .preview(freshPreview))
    }

    /// §10.1 row 6 — a preview answer paints the `.preview` display state
    /// (S3).
    @Test func previewSuccessBecomesDisplayState() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("success"), itemCount: 1, startIndex: 0)
        let service = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: service
        )
        let item = collection.items[0]

        let arrived = await Self.waitFor(
            { viewModel.displayStates[item.id] != .loading },
            "the preview answer must arrive"
        )
        guard arrived else { return }
        #expect(viewModel.displayStates[item.id] == .preview(Self.knownPreview))
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentItemID == item.id)
    }

    /// §10.1 row 7 — a `nil` answer is the sticky `.unavailable` state
    /// (S12, S13); paging away and back never re-requests it (no
    /// auto-retry).
    @Test func nilPreviewBecomesStickyUnavailableWithoutRetry() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("sticky"), itemCount: 3, startIndex: 1)
        let service = RecordingPreviewService(result: nil)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: service
        )
        guard await Self.waitFor(
            { viewModel.displayStates.values.allSatisfy { $0 == .unavailable } },
            "all three window items must reach .unavailable"
        ) else { return }

        viewModel.pageForward() // current 2 — window {2, 1}: nothing new
        viewModel.pageBackward() // current 1 — window {1, 2, 0}: item 0 re-enters

        let total = await service.totalCalls
        #expect(total == 3, "sticky states are never re-requested — no auto-retry (S12/S13), got \(total)")
        #expect(viewModel.displayStates[collection.items[0].id] == .unavailable)
    }

    /// §10.1 row 8 — the prefetch window requests current ± 1 only, the
    /// current item first (RNF-02, design §5.5); nothing beyond the window
    /// is ever requested.
    @Test func prefetchWindowCoversCurrentNeighborsOnlyCurrentFirst() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("window"), itemCount: 5, startIndex: 2)
        let service = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: service
        )
        let windowed = await Self.waitFor(
            { await service.totalCalls == 3 },
            "the window must request exactly three items"
        )
        guard windowed else { return }

        #expect(
            await service.order == [collection.items[2].url, collection.items[3].url, collection.items[1].url],
            "the window is current first, then the two neighbors (§5.5)"
        )
        #expect(await service.calls[collection.items[0].url] == nil, "nothing beyond the window is requested")
        #expect(await service.calls[collection.items[4].url] == nil, "nothing beyond the window is requested")

        viewModel.pageForward() // current 3 — the new forward edge (item 4) loads
        let loaded = await Self.waitFor(
            { await service.totalCalls == 4 },
            "the new edge item must be requested"
        )
        guard loaded else { return }
        #expect(await service.order.last == collection.items[4].url)

        viewModel.pageForward() // current 4, the last item — window {4, 3}: nothing new
        #expect(viewModel.currentIndex == 4)
        #expect(await service.totalCalls == 4, "paging into the last item must not request anything new")
    }

    /// §10.1 row 8 — the dropped-edge request is cancelled when the window
    /// slides (RNF-02): parked in-flight work for item 1 is cancelled as
    /// the window moves to item 3, and the new edge (item 4) is requested.
    @Test func droppedEdgeRequestIsCancelledWhenWindowSlides() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("slide"), itemCount: 5, startIndex: 2)
        let service = RecordingPreviewService(result: nil, holdingUntilCancelled: true)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: service
        )
        let parked = await Self.waitFor(
            { await service.totalCalls == 3 },
            "the window's requests must park on the service"
        )
        guard parked else { return }

        viewModel.pageForward() // current 3 — item 1 drops out of the window

        let cancelledObserved = await Self.waitFor(
            { await service.cancelledCalls == 1 },
            "the dropped-edge request must be cancelled"
        )
        guard cancelledObserved else { return }
        let requeued = await Self.waitFor(
            { await service.totalCalls == 4 },
            "the new edge item must be requested"
        )
        guard requeued else { return }
        #expect(await service.calls[collection.items[4].url] == 1)
        #expect(
            viewModel.displayStates[collection.items[1].id] == nil,
            "the dropped edge's loading state is cleared"
        )
        #expect(viewModel.displayStates[collection.items[4].id] == .loading)
    }

    /// §10.1 row 9 — returning to welcome leaves no paging and no display
    /// state (S16), the preview seam is discarded, and paging calls stay
    /// safe no-ops there.
    @Test func welcomeClearsPagingAndDisplayState() async {
        let collection = Self.makeCollection(folderURL: Self.uniqueFolder("welcome"), itemCount: 3, startIndex: 1)
        let service = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collection,
            repository: ScriptedMediaFolderRepository(results: [collection, nil]),
            previews: service
        )

        await viewModel.handle(entryAction: EntryAction(enteredURL: Self.uniqueFolder("empty")))

        guard case .welcome = viewModel.state else {
            Issue.record("the no-media entry must return to welcome")
            return
        }
        #expect(viewModel.currentIndex == nil, "no paging state in welcome (S16)")
        #expect(viewModel.currentItemID == nil, "no paging state in welcome (S16)")
        #expect(viewModel.displayStates.isEmpty, "no display state in welcome (S16)")
        let discards = await service.discardCount
        #expect(discards == 2, "the welcome drop discards the preview seam too, got \(discards)")

        viewModel.pageForward()
        viewModel.pageBackward()
        viewModel.moveTo(itemID: collection.items[0].id)
        viewModel.scrollGestureDidStart()
        viewModel.scrollGestureDidSettle()
        #expect(viewModel.currentIndex == nil, "paging stays a no-op in welcome")
    }
}

/// Test double for the welcome-state machine (design §9.2). Two modes:
///
/// - scripted `results`, one popped per seam call in call order — for the
///   sequential S5–S7 cases;
/// - `echoingEnteredURL` — each call answers with a collection keyed to
///   the entered URL itself, so in the supersede test the surviving
///   action's own result is identifiable regardless of call interleaving
///   (a held first call defers its pop, which would shift a scripted
///   queue).
///
/// Every call is counted (§7.4: one seam call per entry action). With
/// `holdingFirstCall`, the first call suspends on a continuation gate
/// until `releaseFirstCall()` — making the supersede race deterministic
/// instead of wall-clock timed.
private actor ScriptedMediaFolderRepository: MediaFolderRepository {
    private var results: [MediaCollection?]
    private let echoEnteredURL: Bool
    private let holdFirstCall: Bool
    private var firstCallGate: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    init(
        results: [MediaCollection?] = [],
        echoingEnteredURL: Bool = false,
        holdingFirstCall: Bool = false
    ) {
        self.results = results
        echoEnteredURL = echoingEnteredURL
        holdFirstCall = holdingFirstCall
    }

    /// True while the first call is suspended on the gate.
    var isHoldingFirstCall: Bool {
        firstCallGate != nil
    }

    /// Releases the suspended first call (no-op when not held).
    func releaseFirstCall() {
        firstCallGate?.resume()
        firstCallGate = nil
    }

    func wiringProbe() async -> String {
        "ScriptedMediaFolderRepository"
    }

    func prepareCollection(forEntryAt entryAction: EntryAction) async -> MediaCollection? {
        callCount += 1
        if callCount == 1, holdFirstCall {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                firstCallGate = continuation
            }
        }
        if echoEnteredURL {
            let folder = entryAction.enteredURL
            let item = MediaItem(id: folder, url: folder, name: folder.lastPathComponent, kind: .video)
            return MediaCollection(folderURL: folder, items: [item], startIndex: 0, capturedAt: Date())
        }
        guard !results.isEmpty else { return nil }
        return results.removeFirst()
    }
}

/// Preview-seam double for the §10.1 rows: answers instantly with a
/// scripted result and records every call — per-item counts, global call
/// order, and `discardPreviews()` invocations.
///
/// With `holdingUntilCancelled`, each call spins on `Task.yield()` until
/// its enclosing task is cancelled, then records the cancellation — that
/// makes the dropped-edge cancellation observable deterministically (the
/// view model cancels the task; the parked call observes it).
private actor RecordingPreviewService: MediaPreviewService {
    private let scriptedResult: MediaPreview?
    private let holdUntilCancelled: Bool
    private(set) var calls: [URL: Int] = [:]
    private(set) var order: [URL] = []
    private(set) var discardCount = 0
    private(set) var cancelledCalls = 0

    init(result: MediaPreview?, holdingUntilCancelled: Bool = false) {
        scriptedResult = result
        holdUntilCancelled = holdingUntilCancelled
    }

    var totalCalls: Int {
        order.count
    }

    func preview(for item: MediaItem) async -> MediaPreview? {
        calls[item.url, default: 0] += 1
        order.append(item.url)
        if holdUntilCancelled {
            while Task.isCancelled == false {
                await Task.yield()
            }
            cancelledCalls += 1
            return nil
        }
        return scriptedResult
    }

    func discardPreviews() async {
        discardCount += 1
    }

    func wiringProbe() async -> String {
        "RecordingPreviewService"
    }
}

/// Preview-seam double that parks every call on a continuation gate until
/// released with a scripted value — deterministic supersede races (the
/// stale-paint row of §10.1). `discardPreviews()` is counted, but parked
/// calls are only resumed by `releaseFirst`.
private actor GatedPreviewService: MediaPreviewService {
    private var waiters: [URL: [CheckedContinuation<MediaPreview?, Never>]] = [:]
    private(set) var callCount = 0
    private(set) var discardCount = 0

    func preview(for item: MediaItem) async -> MediaPreview? {
        callCount += 1
        return await withCheckedContinuation { (continuation: CheckedContinuation<MediaPreview?, Never>) in
            waiters[item.url, default: []].append(continuation)
        }
    }

    /// Resumes the oldest parked call for `url` with `value` (no-op when
    /// nothing is parked).
    func releaseFirst(for url: URL, with value: MediaPreview?) {
        guard var queue = waiters[url], !queue.isEmpty else { return }
        let continuation = queue.removeFirst()
        waiters[url] = queue.isEmpty ? nil : queue
        continuation.resume(returning: value)
    }

    func discardPreviews() async {
        discardCount += 1
    }

    func wiringProbe() async -> String {
        "GatedPreviewService"
    }
}
