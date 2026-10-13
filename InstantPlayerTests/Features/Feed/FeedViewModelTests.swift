//
//  FeedViewModelTests.swift
//  InstantPlayerTests
//
//  Welcome-state machine through an injected seam double (E2-S1, design
//  §9.2 — S5–S7, §7.4 no-redundant-work).
//

import AppKit
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

    // MARK: Playback policy (E2-S3 design §10.1 — S1–S11, S14–S15)

    /// The arrange step of the playback rows: script `collection` into a
    /// fresh repository, build the view model around the given player
    /// double, perform the entry action.
    private static func makeViewModel(
        mediaPlayerService: any MediaPlayerService,
        repository: MediaFolderRepository,
        previews: MediaPreviewService
    ) -> FeedViewModel {
        FeedViewModel(
            mediaPlayerService: mediaPlayerService,
            mediaFolderRepository: repository,
            mediaPreviewService: previews
        )
    }

    private static func makeItem(
        _ folderURL: URL,
        named name: String,
        kind: MediaItemKind
    ) -> MediaItem {
        let url = folderURL.appending(path: name)
        return MediaItem(id: url, url: url, name: name, kind: kind)
    }

    private static func makeCollection(
        folderURL: URL,
        items: [MediaItem],
        startIndex: Int
    ) -> MediaCollection {
        MediaCollection(folderURL: folderURL, items: items, startIndex: startIndex, capturedAt: Date())
    }

    private static func openCollection(
        _ collection: MediaCollection,
        mediaPlayerService: any MediaPlayerService,
        previews: MediaPreviewService
    ) async -> FeedViewModel {
        let viewModel = makeViewModel(
            mediaPlayerService: mediaPlayerService,
            repository: ScriptedMediaFolderRepository(results: [collection]),
            previews: previews
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: collection.folderURL))
        return viewModel
    }

    /// Drives one scripted session to its installed, displayed state:
    /// waits for the start call, emits `.readyForDisplay`, waits for the
    /// `.player` display state.
    private static func installPlayback(
        _ item: MediaItem,
        handle: ScriptedMediaPlayback,
        in viewModel: FeedViewModel,
        service: ScriptedMediaPlayerService
    ) async -> Bool {
        let called = await waitFor(
            { service.calls.contains(where: { $0.id == item.id }) },
            "startPlayback must be called for the current video"
        )
        guard called else { return false }
        handle.emit(.readyForDisplay)
        return await waitFor(
            { viewModel.displayStates[item.id] == .player(handle) },
            "the session must install and reach the .player display state"
        )
    }

    /// §10.1 — become-current trigger set (S1): folder open at
    /// `startIndex` starts the starting video.
    @Test func folderOpenAutoPlaysTheStartingVideo() async {
        let folder = Self.uniqueFolder("auto-open")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let item2 = Self.makeItem(folder, named: "c.png", kind: .image)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1, item2], startIndex: 1)
        let players = ScriptedMediaPlayerService(answers: [ScriptedMediaPlayback()])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )

        let started = await Self.waitFor(
            { players.calls == [item1] },
            "folder open must start the startIndex video (S1)"
        )
        guard started else { return }
        #expect(viewModel.currentIndex == 1)
    }

    /// §10.1 — images are never started (S4): an image `startIndex` opens
    /// the feed with no playback attempt at all.
    @Test func imageStartIndexNeverStartsPlayback() async {
        let folder = Self.uniqueFolder("auto-image")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.png", kind: .image)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 1)
        let players = ScriptedMediaPlayerService()
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )

        let painted = await Self.waitFor(
            {
                if case .preview = viewModel.displayStates[item1.id] {
                    return true
                }
                return false
            },
            "the image page must reach its preview state"
        )
        guard painted else { return }
        #expect(players.calls.isEmpty, "images have no playback semantics (S4)")
    }

    /// §10.1 — settle-only start (S2): a mid-gesture `moveTo` changes the
    /// index but never starts playback (the incoming item keeps its
    /// poster); the settle starts the settled item. The index change away
    /// from a playing session stops it synchronously (S9).
    @Test func midGestureMoveToNeverStartsSettleDoes() async {
        let folder = Self.uniqueFolder("settle-only")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id) // mid-gesture landing
        #expect(players.calls == [item0], "a mid-gesture moveTo must never start playback (S2)")
        #expect(handle0.stopCount == 1, "the index change stops the old session synchronously (S9)")
        viewModel.scrollGestureDidSettle()

        let started = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the settle must start the settled item (S1, S2)"
        )
        guard started else { return }
        handle1.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item1.id] == .player(handle1) },
            "the settled session must install and paint"
        )
    }

    /// §10.1 — the arrow-key page is its own settle (design §3's taken
    /// fallback): `pageForward()` starts the clamped landing item
    /// immediately — programmatic page animations emit no phase signals,
    /// and the arrow landing is deterministic.
    @Test func arrowPageForwardStartsTheLandingItemImmediately() async {
        let folder = Self.uniqueFolder("arrow-fwd")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward()
        let started = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the arrow page must start the landing item (S1 — the arrow action is its own settle)"
        )
        guard started else { return }
        #expect(viewModel.currentIndex == 1)
        #expect(handle0.stopCount == 1, "the departure stops the old session synchronously (S9)")
        handle1.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item1.id] == .player(handle1) },
            "the arrow-started session must install and paint"
        )
    }

    /// §10.1 — the arrow-key page backward starts the landing item too,
    /// as a fresh session (S1, S10 — nothing carries across visits).
    @Test func arrowPageBackwardStartsTheLandingItemImmediately() async {
        let folder = Self.uniqueFolder("arrow-back")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 1)
        let handleStart = ScriptedMediaPlayback()
        let handleBack = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handleStart, handleBack])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item1, handle: handleStart, in: viewModel, service: players) else { return }

        viewModel.pageBackward()
        let started = await Self.waitFor(
            { players.calls == [item1, item0] },
            "the arrow page backward must start the landing item (S1)"
        )
        guard started else { return }
        #expect(viewModel.currentIndex == 0)
        #expect(handleStart.resumeCount == 0, "no resume — a fresh session (S10)")
        handleBack.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .player(handleBack) },
            "the arrow-started session must install and paint"
        )
    }

    /// §10.1 — toggles work immediately after arrow paging (the review
    /// defect): the arrow page is its own settle, so the mid-gesture
    /// toggle guard (S7) can never wedge — the new session pauses on the
    /// first press right after the page.
    @Test func togglesWorkImmediatelyAfterArrowPaging() async {
        let folder = Self.uniqueFolder("arrow-toggle")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward()
        let started = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the arrow page must start the landing item (S1 — the arrow action is its own settle)"
        )
        guard started else { return }
        handle1.emit(.readyForDisplay)
        let installed = await Self.waitFor(
            { viewModel.displayStates[item1.id] == .player(handle1) },
            "the arrow-started session must install and paint"
        )
        guard installed else { return }

        viewModel.togglePlayback()
        #expect(
            handle1.pauseCount == 1,
            "spacebar right after an arrow page must pause the new session (S5 — no dead toggles)"
        )
        #expect(handle0.pauseCount == 0, "the old session was stopped, never toggled (S9)")

        viewModel.togglePlayback()
        #expect(handle1.resumeCount == 1, "the second press resumes (S5)")
    }

    /// §10.1 — unmuted auto-play at the double (S3): the seam contract is
    /// "startPlayback = play, unmuted", so a fresh session is considered
    /// playing the moment it installs — the first toggle pauses. The pause
    /// changes nothing visible but the frozen frame (S8): the display
    /// state stays `.player`. (The mute truth is asserted at the
    /// conformance, §10.2.)
    @Test func freshSessionAutoPlaysAndPauseLeavesThePlayerState() async {
        let folder = Self.uniqueFolder("autoplay-pause")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.togglePlayback()
        #expect(handle0.pauseCount == 1, "a fresh session auto-plays — the first toggle pauses (S3, S5)")
        #expect(handle0.resumeCount == 0)
        #expect(
            viewModel.displayStates[item0.id] == .player(handle0),
            "pause shows only the frozen frame — no chrome, no state change (S8)"
        )

        viewModel.togglePlayback()
        #expect(handle0.resumeCount == 1, "the second toggle resumes (S5)")
    }

    /// §10.1 — the tap route (S6): a click on the settled current page
    /// toggles; a click on a non-current page is a no-op (S7). A
    /// double-click is two single clicks — no meaning of its own (spec
    /// non-goal).
    @Test func tapTogglesOnlyTheCurrentPage() async {
        let folder = Self.uniqueFolder("tap-guard")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.togglePlaybackFromTap(itemID: item0.id)
        #expect(handle0.pauseCount == 1, "a click on the current page pauses (S6)")

        viewModel.togglePlaybackFromTap(itemID: item1.id)
        #expect(handle0.pauseCount == 1, "a click on a non-current page is a no-op (S7)")

        viewModel.togglePlaybackFromTap(itemID: item0.id)
        #expect(handle0.resumeCount == 1, "the second click on the current page resumes — two single clicks (S6)")
    }

    /// §10.1 — any toggle while a paging gesture is in flight is a no-op
    /// (S7); the guard releases at settle.
    @Test func toggleWhilePagingIsANoOp() async {
        let folder = Self.uniqueFolder("gesture-guard")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.scrollGestureDidStart()
        viewModel.togglePlayback()
        viewModel.togglePlaybackFromTap(itemID: item0.id)
        #expect(handle0.pauseCount == 0, "toggles mid-gesture are consumed no-ops (S7)")

        viewModel.moveTo(itemID: item0.id) // snap-back
        viewModel.scrollGestureDidSettle()
        viewModel.togglePlayback()
        #expect(handle0.pauseCount == 1, "the guard releases at settle (S7)")
        #expect(players.calls == [item0], "a zero-net gesture must not restart the session")
    }

    /// §10.1 — an image page has no playback (S4): paging onto an image
    /// stops the video and never starts one; toggles there are consumed
    /// no-ops (S7).
    @Test func imagePageStopsAndNeverStartsToggleIsNoOp() async {
        let folder = Self.uniqueFolder("image-page")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.png", kind: .image)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        #expect(handle0.stopCount == 1, "paging onto the image stops the video (S9)")
        #expect(players.calls == [item0], "images are never started (S4)")

        viewModel.togglePlayback()
        viewModel.togglePlaybackFromTap(itemID: item1.id)
        #expect(handle0.pauseCount == 0, "toggles on an image page are no-ops (S4, S7)")
    }

    /// §10.1 — stop-on-away (S9): the old session is stopped synchronously
    /// — `stop()` is already recorded when the paging call returns (design
    /// §8(2): no audio past the page turn).
    @Test func pagingAwayStopsBeforePagingReturns() async {
        let folder = Self.uniqueFolder("stop-on-away")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward()
        #expect(handle0.stopCount == 1, "stop() must be recorded synchronously with the page change (S9)")
    }

    /// §10.1 / design §4 implementation correction — stop-on-away display
    /// hygiene: the departed video's `.player` state reverts to its poster
    /// state, so the cell never keeps a stopped player surface (the review
    /// defect: revisiting a video showed no picture).
    @Test func pagingAwayRevertsDepartedVideoToItsPosterState() async {
        let folder = Self.uniqueFolder("revert-poster")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let previews = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: previews
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward()

        #expect(
            viewModel.displayStates[item0.id] == .preview(Self.knownPreview),
            "the departed item must revert to its poster state — never keep a stopped .player (design §4)"
        )
    }

    /// §10.1 / design §4 implementation correction — a revisit after the
    /// revert installs a FRESH session whose surface paints: the display
    /// state travels poster → `.player(newHandle)`, never
    /// `.player(oldHandle)` (S10's fresh start, made visible).
    @Test func revisitingARevertedVideoPaintsAFreshSurface() async {
        let folder = Self.uniqueFolder("revisit-fresh")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let handle2 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1, handle2])
        let previews = RecordingPreviewService(result: Self.knownPreview)
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: previews
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward() // away — item1's arrow start answers with handle1
        let forward = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .preview(Self.knownPreview) },
            "the departed item must revert to its poster state"
        )
        guard forward else { return }

        viewModel.pageBackward() // revisit — a fresh session for item0
        let back = await Self.waitFor(
            { players.calls == [item0, item1, item0] },
            "the revisit must start a fresh session (S10)"
        )
        guard back else { return }
        #expect(handle2 !== handle0, "a fresh handle, not the old session (S10)")
        handle2.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .player(handle2) },
            "the fresh session's surface must paint — poster → .player(newHandle)"
        )
    }

    /// §10.1 / design §4 implementation correction — a poster answer that
    /// arrives while the item is live-playing never paints over the
    /// surface; it parks and becomes the stop-on-away revert target.
    @Test func latePosterWhilePlayingParksForTheRevert() async {
        let folder = Self.uniqueFolder("late-poster")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let previews = GatedPreviewService()
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: previews
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        await previews.releaseFirst(for: item0.url, with: Self.knownPreview)
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            viewModel.displayStates[item0.id] == .player(handle0),
            "the late poster must not paint over the live surface"
        )

        viewModel.pageForward()
        #expect(
            viewModel.displayStates[item0.id] == .preview(Self.knownPreview),
            "the parked late poster is the revert target on stop-on-away (design §4)"
        )
    }

    /// §10.1 — restart-on-revisit (S10): paging back starts a FRESH
    /// session — no resume, nothing carried across visits; the old handle
    /// is never resumed or restarted, and a new handle is vended.
    @Test func revisitingStartsAFreshSession() async {
        let folder = Self.uniqueFolder("revisit")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let handle2 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1, handle2])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        let forward = await Self.waitFor(
            { players.calls == [item0, item1] },
            "paging forward must start the new current item"
        )
        guard forward else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item0.id)
        viewModel.scrollGestureDidSettle()
        let back = await Self.waitFor(
            { players.calls == [item0, item1, item0] },
            "paging back must start a fresh session for the revisited video (S10)"
        )
        guard back else { return }

        #expect(handle0.resumeCount == 0, "no resume across visits (S10)")
        #expect(handle0.restartCount == 0, "nothing carries across visits (S10)")
        #expect(handle2 !== handle0, "a fresh session, not the old one (S10)")
        handle2.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .player(handle2) },
            "the fresh session must install and paint"
        )
    }

    /// §10.1 — loop in place (S11): `.reachedEnd` restarts the SAME
    /// handle; the index is untouched; no neighbor is ever started; the
    /// bridge survives restarts, so the loop repeats.
    @Test func reachedEndRestartsSameHandleWithoutAdvancing() async {
        let folder = Self.uniqueFolder("loop")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        handle0.emit(.reachedEnd)
        let restarted = await Self.waitFor(
            { handle0.restartCount == 1 },
            ".reachedEnd must restart the same handle (S11)"
        )
        guard restarted else { return }
        #expect(viewModel.currentIndex == 0, "the index is untouched (S11 — no auto-advance)")
        #expect(players.calls == [item0], "the neighbor is never started (S11)")

        handle0.emit(.reachedEnd)
        _ = await Self.waitFor(
            { handle0.restartCount == 2 },
            "the loop must repeat on every end (S11)"
        )
    }

    /// §10.1 — `startPlayback` → `nil` is the unified failure answer (S14,
    /// S15): sticky `.unavailable`, never re-attempted this session
    /// (per-axis stickiness — paging away and back does not retry), and
    /// toggles on the failed current item are no-ops.
    @Test func nilStartBecomesStickyUnavailableWithoutRetry() async {
        let folder = Self.uniqueFolder("nil-start")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [nil, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )

        let failed = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .unavailable },
            "a nil start must show the sticky unavailable state (S14, S15)"
        )
        guard failed else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        let forward = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the neighbor video must start normally"
        )
        guard forward else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item0.id)
        viewModel.scrollGestureDidSettle()
        _ = await Self.waitFor(
            { viewModel.currentItemID == item0.id },
            "the failed item must be reachable again"
        )
        #expect(players.calls == [item0, item1], "the failed item is never re-attempted (design §7)")
        #expect(viewModel.displayStates[item0.id] == .unavailable, "the unavailable state is sticky")

        viewModel.togglePlayback()
        #expect(handle1.pauseCount == 0, "toggling the failed current item is a no-op (S7)")
    }

    /// §10.1 — a mid-play `.failed` event stops the session and shows the
    /// sticky `.unavailable` (S14); the item is never re-attempted.
    @Test func failedEventStopsAndBecomesStickyUnavailable() async {
        let folder = Self.uniqueFolder("failed-event")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        handle0.emit(.failed)
        let failed = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .unavailable },
            "a .failed event must show the sticky unavailable state (S14)"
        )
        guard failed else { return }
        #expect(handle0.stopCount == 1, "the .failed event stops the session (design §7)")

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        let forward = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the neighbor video must start normally"
        )
        guard forward else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item0.id)
        viewModel.scrollGestureDidSettle()
        _ = await Self.waitFor(
            { viewModel.currentItemID == item0.id },
            "the failed item must be reachable again"
        )
        #expect(players.calls == [item0, item1], "the failed item is never re-attempted (design §7)")
        #expect(viewModel.displayStates[item0.id] == .unavailable)
    }

    /// §10.1 — per-axis stickiness (design §7): a failed POSTER does not
    /// block the playback attempt (S1 is unconditional); playback
    /// succeeding shows `.player` — honest recovery.
    @Test func posterFailureDoesNotBlockThePlaybackAttempt() async {
        let folder = Self.uniqueFolder("poster-axis")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: RecordingPreviewService(result: nil) // the poster axis fails
        )

        let attempted = await Self.waitFor(
            { players.calls == [item0] },
            "the playback attempt must happen despite the poster failure (design §7)"
        )
        guard attempted else { return }
        handle0.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item0.id] == .player(handle0) },
            "playback succeeding must show .player — honest recovery (design §7)"
        )
    }

    /// §10.1 — late events from a stopped handle never paint or sound
    /// (design §3's braces): the dropped handle's `.failed` must neither
    /// turn the item unavailable nor stop anything again.
    @Test func eventsFromAStoppedHandleNeverPaint() async {
        let folder = Self.uniqueFolder("brace-stopped")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.pageForward() // stops and drops handle0
        handle0.emit(.failed) // emitted after stop — must be inert
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            viewModel.displayStates[item0.id] != .unavailable,
            "a stopped handle's late event never paints (design §3)"
        )
        #expect(handle0.stopCount == 1, "the stopped handle is never stopped again through the event path")
    }

    /// §10.1 — a superseded handle's late event never paints and never
    /// touches the live session (design §3 brace 2 — handle identity).
    @Test func supersededHandleEventsNeverTouchTheLiveSession() async {
        let folder = Self.uniqueFolder("brace-identity")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0, handle1])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        let superseded = await Self.waitFor(
            { players.calls == [item0, item1] },
            "the successor session must start"
        )
        guard superseded else { return }
        handle1.emit(.readyForDisplay)
        let live = await Self.waitFor(
            { viewModel.displayStates[item1.id] == .player(handle1) },
            "the live session must paint"
        )
        guard live else { return }

        handle0.emit(.failed) // late, superseded
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            viewModel.displayStates[item0.id] != .unavailable,
            "a superseded handle's late event never paints (design §3 brace 2)"
        )
        #expect(
            viewModel.displayStates[item1.id] == .player(handle1),
            "the live session is untouched by the stale handle"
        )
        #expect(handle1.stopCount == 0, "the stale handle's event must not stop the live session")
    }

    /// §10.1 — a superseded `startPlayback` result never installs (design
    /// §3 brace 3): the start is parked in the seam, the current item
    /// changes, and the released answer must be stopped and dropped,
    /// never installed.
    @Test func supersededStartResultNeverInstalls() async {
        let folder = Self.uniqueFolder("brace-generation")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let item1 = Self.makeItem(folder, named: "b.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0, item1], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let handle1 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle1], holdingFirstCall: true)
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )

        let parked = await Self.waitFor(
            { players.isHoldingFirstCall },
            "the first start must park on the gate"
        )
        guard parked else { return }

        viewModel.scrollGestureDidStart()
        viewModel.moveTo(itemID: item1.id)
        viewModel.scrollGestureDidSettle()
        let superseded = await Self.waitFor(
            { players.calls.count == 2 },
            "the settle must start the new current item"
        )
        guard superseded else { return }

        players.releaseFirstCall(with: handle0)
        let dropped = await Self.waitFor(
            { handle0.stopCount == 1 },
            "the superseded result must be stopped, never installed (design §3 brace 3)"
        )
        guard dropped else { return }
        #expect(viewModel.displayStates[item0.id] != .player(handle0))

        handle1.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[item1.id] == .player(handle1) },
            "the fresh session must install and paint"
        )
    }

    /// §10.1 — the replace-in-place generation guard (design §3 brace 3):
    /// a parked start for the replaced collection is stopped and never
    /// installs; the new collection starts at its own `startIndex`.
    @Test func replaceInPlaceDropsTheSupersededStart() async {
        let folderA = Self.uniqueFolder("replace-brace-a")
        let folderB = Self.uniqueFolder("replace-brace-b")
        let itemA = Self.makeItem(folderA, named: "a.mp4", kind: .video)
        let itemB = Self.makeItem(folderB, named: "b.mp4", kind: .video)
        let collectionA = Self.makeCollection(folderURL: folderA, items: [itemA], startIndex: 0)
        let collectionB = Self.makeCollection(folderURL: folderB, items: [itemB], startIndex: 0)
        let handleA = ScriptedMediaPlayback()
        let handleB = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handleB], holdingFirstCall: true)
        let viewModel = Self.makeViewModel(
            mediaPlayerService: players,
            repository: ScriptedMediaFolderRepository(results: [collectionA, collectionB]),
            previews: StubMediaPreviewService()
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: folderA))

        let parked = await Self.waitFor(
            { players.isHoldingFirstCall },
            "the replaced collection's start must park on the gate"
        )
        guard parked else { return }

        await viewModel.handle(entryAction: EntryAction(enteredURL: folderB))
        let started = await Self.waitFor(
            { players.calls == [itemA, itemB] },
            "the new collection must start at its own startIndex (S1)"
        )
        guard started else { return }

        players.releaseFirstCall(with: handleA)
        let dropped = await Self.waitFor(
            { handleA.stopCount == 1 },
            "the superseded session must be stopped, never installed (design §3 brace 3)"
        )
        guard dropped else { return }
        #expect(viewModel.displayStates[itemA.id] == nil, "the superseded session never paints")

        handleB.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[itemB.id] == .player(handleB) },
            "the new collection's session must install and paint"
        )
    }

    /// §10.1 — welcome teardown (design §3): the no-media entry stops and
    /// drops the session; toggles afterwards are quiet no-ops.
    @Test func welcomeStopsAndDropsTheSession() async {
        let folder = Self.uniqueFolder("welcome-teardown")
        let item0 = Self.makeItem(folder, named: "a.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item0], startIndex: 0)
        let handle0 = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [handle0])
        let viewModel = await Self.openCollection(
            collection,
            mediaPlayerService: players,
            previews: StubMediaPreviewService()
        )
        guard await Self.installPlayback(item0, handle: handle0, in: viewModel, service: players) else { return }

        await viewModel.handle(entryAction: EntryAction(enteredURL: Self.uniqueFolder("empty")))
        guard case .welcome = viewModel.state else {
            Issue.record("the no-media entry must return to welcome")
            return
        }
        #expect(handle0.stopCount == 1, "welcome must stop the session (design §3)")
        viewModel.togglePlayback()
        #expect(handle0.pauseCount == 0, "the handle is dropped — toggles are no-ops (design §3)")
    }

    /// §10.1 — a fresh entry action resets playback stickiness (design
    /// §7's "way out"): the same item id in a replaced collection is
    /// attempted again even though it failed in the previous one.
    @Test func freshEntryResetsPlaybackFailureStickiness() async {
        let folderA = Self.uniqueFolder("reset-a")
        let itemURL = folderA.appending(path: "same.mp4")
        let itemA = MediaItem(id: itemURL, url: itemURL, name: "same.mp4", kind: .video)
        let collectionA = Self.makeCollection(folderURL: folderA, items: [itemA], startIndex: 0)
        let folderB = Self.uniqueFolder("reset-b")
        let itemB = MediaItem(id: itemURL, url: itemURL, name: "same.mp4", kind: .video)
        let collectionB = Self.makeCollection(folderURL: folderB, items: [itemB], startIndex: 0)
        let handleB = ScriptedMediaPlayback()
        let players = ScriptedMediaPlayerService(answers: [nil, handleB])
        let viewModel = Self.makeViewModel(
            mediaPlayerService: players,
            repository: ScriptedMediaFolderRepository(results: [collectionA, collectionB]),
            previews: StubMediaPreviewService()
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: folderA))

        let failed = await Self.waitFor(
            { viewModel.displayStates[itemA.id] == .unavailable },
            "the item must fail in the first collection"
        )
        guard failed else { return }

        await viewModel.handle(entryAction: EntryAction(enteredURL: folderB))
        let retried = await Self.waitFor(
            { players.calls == [itemA, itemB] },
            "a fresh entry action must reset playback stickiness (design §7)"
        )
        guard retried else { return }
        handleB.emit(.readyForDisplay)
        _ = await Self.waitFor(
            { viewModel.displayStates[itemB.id] == .player(handleB) },
            "the re-attempted session must install and paint"
        )
    }

    // MARK: Scrub & seek policy (E3-S1 design §10.1 — S1–S15)

    /// The arrange step of the scrub/seek rows: a one-video collection,
    /// the scripted handle (duration scripted) installed and displayed,
    /// and the manual clock injected into the view model. Returns the
    /// view model, its player double, and the collection.
    private static func arrangeSeekRow(
        handle: ScriptedMediaPlayback,
        duration: TimeInterval,
        clock: ManualClock,
        itemCount: Int = 1
    ) async -> (FeedViewModel, ScriptedMediaPlayerService, MediaCollection) {
        let folder = Self.uniqueFolder("seek")
        let items = (0 ..< itemCount).map { Self.makeItem(folder, named: "v\($0).mp4", kind: .video) }
        let collection = Self.makeCollection(folderURL: folder, items: items, startIndex: 0)
        handle.duration = duration
        let players = ScriptedMediaPlayerService(answers: [handle])
        let viewModel = FeedViewModel(
            mediaPlayerService: players,
            mediaFolderRepository: ScriptedMediaFolderRepository(results: [collection]),
            mediaPreviewService: StubMediaPreviewService(),
            now: { clock.time }
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: folder))
        let installed = await Self.installPlayback(
            collection.items[0], handle: handle, in: viewModel, service: players
        )
        guard installed else {
            Issue.record("arrange: the session must install and paint")
            return (viewModel, players, collection)
        }
        return (viewModel, players, collection)
    }

    /// The recorded seeks as parallel arrays — tuples are not `Equatable`,
    /// so the rows compare seconds and tolerances separately.
    private static func seekSeconds(_ handle: ScriptedMediaPlayback) -> [TimeInterval] {
        handle.seeks.map(\.seconds)
    }

    private static func seekTolerances(_ handle: ScriptedMediaPlayback) -> [MediaSeekTolerance] {
        handle.seeks.map(\.tolerance)
    }

    /// Drag machine (S5–S8), the was-playing case: begin records the
    /// intent and pauses gesture-scoped, change issues `.preview` to the
    /// mapped target and moves the displayed position, end issues
    /// `.exact` to the final target and resumes.
    @Test func dragMachinePlayingCasePausePreviewExactResume() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.beginScrub(itemID: item.id)
        #expect(handle.pauseCount == 1, "begin pauses for the drag (S5)")

        viewModel.scrubChanged(itemID: item.id, fraction: 0.5)
        #expect(
            Self.seekSeconds(handle) == [50] && Self.seekTolerances(handle) == [.preview],
            "the change issues one tolerant preview seek to the mapped target (S6)"
        )
        #expect(viewModel.displayedPosition == 50, "the labels/thumb track the pointer exactly (S5)")

        viewModel.scrubEnded(itemID: item.id, fraction: 0.75)
        #expect(
            Self.seekSeconds(handle).last == 75 && Self.seekTolerances(handle).last == .exact,
            "the release issues the frame-exact seek to the final target (S7)"
        )
        #expect(handle.resumeCount == 1, "was-playing → resume (S8)")
        #expect(handle.pauseCount == 1, "no further pause")
        #expect(viewModel.displayedPosition == 75)
    }

    /// Drag machine (S8), the was-paused case: the release stays paused on
    /// the frozen frame — no resume.
    @Test func dragMachineWasPausedStaysPausedOnTheFrozenFrame() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.togglePlayback() // pause (S8's prior state)
        #expect(handle.pauseCount == 1)
        viewModel.beginScrub(itemID: item.id)
        #expect(handle.pauseCount == 2, "begin pauses again — the gesture-scoped pause")
        viewModel.scrubChanged(itemID: item.id, fraction: 0.25)
        viewModel.scrubEnded(itemID: item.id, fraction: 0.25)

        #expect(
            Self.seekSeconds(handle).last == 25 && Self.seekTolerances(handle).last == .exact,
            "the release lands the exact seek (S7)"
        )
        #expect(handle.resumeCount == 0, "was-paused → stays paused on the frozen frame (S8)")
    }

    /// `beginScrub` must not flip `isPlaybackPaused` (S5's gesture-scope):
    /// observed through the toggle — the untouched (playing) state pauses
    /// again; a flipped state would have resumed.
    @Test func beginScrubDoesNotFlipIsPlaybackPaused() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )

        viewModel.beginScrub(itemID: collection.items[0].id)
        viewModel.togglePlayback()

        #expect(
            handle.pauseCount == 2 && handle.resumeCount == 0,
            "the toggle paused again — isPlaybackPaused was never flipped by the drag (S5)"
        )
    }

    /// Key steps (S2, S9): ±5 s computed from `displayedPosition` — two
    /// quick presses net exactly 10 s (no drift), auto-repeat = repeated
    /// steps.
    @Test func keyboardStepsAreFiveSecondsFromDisplayedPositionWithoutDrift() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, _) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)

        viewModel.seekForwardByKeyboard()
        viewModel.seekForwardByKeyboard()
        viewModel.seekBackwardByKeyboard()

        #expect(
            Self.seekSeconds(handle) == [5, 10, 5] && Self.seekTolerances(handle) == [.exact, .exact, .exact],
            "each step is exact ±5 s from the displayed position — two presses net 10 s (S2, S9)"
        )
        #expect(viewModel.displayedPosition == 5)
    }

    /// Key steps (S10): rate untouched in both play states — the seek
    /// never pauses or resumes.
    @Test func keyboardStepsLeavePlayPauseUntouchedInBothStates() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, _) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)

        viewModel.seekForwardByKeyboard()
        #expect(handle.pauseCount == 0 && handle.resumeCount == 0, "playing: the step changed nothing (S10)")

        viewModel.togglePlayback() // pause
        viewModel.seekBackwardByKeyboard()
        #expect(
            handle.pauseCount == 1 && handle.resumeCount == 0,
            "paused: the step changed nothing either (S10)"
        )
    }

    /// Track click (S11): `.exact` to the mapped target; never
    /// `pause()`/`resume()` — the play/pause state is untouched.
    @Test func trackClickSeeksExactWithoutToggling() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)

        viewModel.seekFromTrackClick(itemID: collection.items[0].id, fraction: 0.4)

        #expect(
            Self.seekSeconds(handle) == [40] && Self.seekTolerances(handle) == [.exact],
            "the click seeks exactly to the mapped target (S11)"
        )
        #expect(
            handle.pauseCount == 0 && handle.resumeCount == 0 && handle.restartCount == 0,
            "a click must never toggle (S11, S10)"
        )
    }

    /// Guard matrix (S12): seek input on a non-current page is a consumed
    /// no-op — the spy records nothing.
    @Test func seekInputsOnANonCurrentPageAreQuietNoOps() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock, itemCount: 2
        )
        let departed = collection.items[0]

        viewModel.pageForward() // item 1 becomes current (its own seam answer)
        viewModel.beginScrub(itemID: departed.id)
        viewModel.scrubChanged(itemID: departed.id, fraction: 0.5)
        viewModel.scrubEnded(itemID: departed.id, fraction: 0.5)
        viewModel.seekFromTrackClick(itemID: departed.id, fraction: 0.5)

        #expect(
            handle.seeks.isEmpty && handle.pauseCount == 0 && handle.resumeCount == 0,
            "non-current seek input must be a consumed no-op (S12)"
        )
    }

    /// Guard matrix (S12): seek input while a paging gesture is in flight
    /// is a consumed no-op.
    @Test func seekInputsDuringAPagingGestureAreQuietNoOps() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.scrollGestureDidStart()
        viewModel.seekForwardByKeyboard()
        viewModel.seekFromTrackClick(itemID: item.id, fraction: 0.5)
        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 0.5)

        #expect(
            handle.seeks.isEmpty && handle.pauseCount == 0,
            "mid-gesture seek input must be a consumed no-op (S12)"
        )
        viewModel.scrollGestureDidSettle()
    }

    /// Guard matrix (S4, S12): an image page has no bar and no seek —
    /// mouse movement shows nothing, click seeks nothing.
    @Test func seekInputsOnAnImagePageAreQuietNoOps() async {
        let folder = Self.uniqueFolder("seek-image")
        let image = Self.makeItem(folder, named: "pic.png", kind: .image)
        let collection = Self.makeCollection(folderURL: folder, items: [image], startIndex: 0)
        let clock = ManualClock()
        let viewModel = FeedViewModel(
            mediaPlayerService: ScriptedMediaPlayerService(),
            mediaFolderRepository: ScriptedMediaFolderRepository(results: [collection]),
            mediaPreviewService: StubMediaPreviewService(),
            now: { clock.time }
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: folder))
        let painted = await Self.waitFor(
            { viewModel.displayStates[image.id] != nil },
            "the image page must reach its preview state"
        )
        guard painted else { return }

        viewModel.noteMouseMoved(itemID: image.id)
        viewModel.seekFromTrackClick(itemID: image.id, fraction: 0.5)

        #expect(
            viewModel.controlBarModel == nil,
            "an image page has no bar — movement shows nothing (S4)"
        )
    }

    /// Guard matrix (S12): the neutral unavailable state (sticky playback
    /// failure) has no bar and no seek.
    @Test func seekInputsOnAnUnavailableItemAreQuietNoOps() async {
        let folder = Self.uniqueFolder("seek-unavailable")
        let item = Self.makeItem(folder, named: "broken.mp4", kind: .video)
        let collection = Self.makeCollection(folderURL: folder, items: [item], startIndex: 0)
        let clock = ManualClock()
        let viewModel = FeedViewModel(
            mediaPlayerService: ScriptedMediaPlayerService(answers: [nil]),
            mediaFolderRepository: ScriptedMediaFolderRepository(results: [collection]),
            mediaPreviewService: StubMediaPreviewService(),
            now: { clock.time }
        )
        await viewModel.handle(entryAction: EntryAction(enteredURL: folder))
        let failed = await Self.waitFor(
            { viewModel.displayStates[item.id] == .unavailable },
            "the nil seam answer must become the sticky unavailable state"
        )
        guard failed else { return }

        viewModel.noteMouseMoved(itemID: item.id)
        viewModel.seekFromTrackClick(itemID: item.id, fraction: 0.5)

        #expect(
            viewModel.controlBarModel == nil,
            "the unavailable state has no bar (S12)"
        )
    }

    /// Guard matrix (S12): keyboard seek during a scrub drag is a
    /// consumed no-op — the release lands on the scrubber's point
    /// regardless, so a mid-drag key seek could never survive.
    @Test func keyboardSeekDuringAScrubDragIsAQuietNoOp() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 0.5)
        let recordedDuringDrag = handle.seeks.count

        viewModel.seekForwardByKeyboard()
        viewModel.seekBackwardByKeyboard()

        #expect(
            handle.seeks.count == recordedDuringDrag,
            "the mid-drag keyboard steps must record nothing (S12)"
        )
        #expect(viewModel.displayedPosition == 50, "the drag target still owns the display")
    }

    /// Guard matrix (S13's defensive row): a `duration <= 0` session
    /// rejects every seek input — quietly.
    @Test func seekInputsWithAZeroDurationSessionAreQuietNoOps() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 0, clock: clock
        )
        let item = collection.items[0]

        viewModel.noteMouseMoved(itemID: item.id)
        viewModel.seekFromTrackClick(itemID: item.id, fraction: 0.5)
        viewModel.seekForwardByKeyboard()

        #expect(
            handle.seeks.isEmpty && handle.restartCount == 0,
            "a duration-less session rejects seek input (S13's defensive row)"
        )
    }

    /// Clamping (S13): out-of-range targets clamp to `[0, duration]` —
    /// the clamp also doubles as input validation for unbounded geometry.
    @Test func clampedTargetsAtBothEnds() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)
        let item = collection.items[0]

        viewModel.seekFromTrackClick(itemID: item.id, fraction: -0.5)
        #expect(
            Self.seekSeconds(handle) == [0] && Self.seekTolerances(handle) == [.exact],
            "below-range clamps to 0 — an ordinary clamped seek, no special case"
        )

        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 2.0)
        #expect(
            viewModel.displayedPosition == 100,
            "above-range clamps to the duration (S13)"
        )
        viewModel.scrubEnded(itemID: item.id, fraction: 0.5)
    }

    /// End handover (S14), the playing case — shared by the click and the
    /// key step: `target == duration` after clamping restarts the SAME
    /// video; the index is never touched (product R15).
    @Test func endHandoverFromClickAndKeyStepsRestartsPlaying() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.seekFromTrackClick(itemID: item.id, fraction: 1.0)
        #expect(handle.restartCount == 1, "the click at the end restarts the same video (S14, D26)")
        #expect(handle.seeks.isEmpty, "the handover is not a seek (D26's restart)")
        #expect(viewModel.currentItemID == item.id, "the index is never touched (R15)")

        viewModel.seekFromTrackClick(itemID: item.id, fraction: 0.98)
        viewModel.seekForwardByKeyboard() // 98 + 5 clamps to the duration
        #expect(handle.restartCount == 2, "the key step at the end shares the rule (S14)")
        #expect(
            Self.seekSeconds(handle) == [98] && Self.seekTolerances(handle) == [.exact],
            "only the ordinary seek was issued"
        )
        #expect(viewModel.currentItemID == item.id, "still no auto-advance (R15)")
    }

    /// End handover (S14), the paused case: seek to 0 `.exact` and stay
    /// paused on the frozen frame at the beginning.
    @Test func endHandoverFromPausedClickSeeksZeroAndStaysPaused() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )

        viewModel.togglePlayback() // pause — the prior state
        viewModel.seekFromTrackClick(itemID: collection.items[0].id, fraction: 1.0)

        #expect(handle.restartCount == 0, "paused → no restart (S14)")
        #expect(
            Self.seekSeconds(handle) == [0] && Self.seekTolerances(handle) == [.exact],
            "paused → the handover seeks to the beginning (S14)"
        )
        #expect(handle.resumeCount == 0, "and stays paused on the frozen frame (S14)")
    }

    /// End handover (S14), the drag-release case: `wasPlayingBeforeDrag`
    /// decides — was-playing restarts even though the handle was paused
    /// for the gesture.
    @Test func endHandoverFromDragReleaseFollowsWasPlaying() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 0.9)
        viewModel.scrubEnded(itemID: item.id, fraction: 1.0)

        #expect(handle.restartCount == 1, "was-playing → the release at the end restarts (S14)")
        #expect(viewModel.currentItemID == item.id, "the index is never touched (R15)")
    }

    /// Bar visibility (S3): mouse movement over the current video page
    /// shows the bar and arms the 3 s idle deadline.
    @Test func mouseMovementOnTheCurrentVideoPageShowsAndArmsTheBar() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        #expect(
            viewModel.controlBarModel?.isVisible == false,
            "before any movement the bar exists hidden-at-rest (design §7)"
        )
        viewModel.noteMouseMoved(itemID: item.id)
        #expect(viewModel.controlBarModel?.isVisible == true, "movement shows the bar (S3)")

        clock.time += 4 // past the 3 s deadline — then let the task observe it
        let hidden = await Self.waitFor(
            { viewModel.controlBarModel?.isVisible == false },
            "the armed 3 s idle deadline must hide the bar (S3)"
        )
        guard hidden else { return }
        #expect(
            viewModel.controlBarModel != nil,
            "hidden is not absent — the live player page keeps its model (design §7)"
        )
    }

    /// Bar visibility (S3(a)): a scrub drag suspends the idle policy
    /// entirely — the bar cannot hide mid-drag even when the would-be
    /// deadline passes — and the countdown restarts after release.
    @Test func scrubDragSuspendsTheIdlePolicyAndReleaseRearmsIt() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.noteMouseMoved(itemID: item.id)
        #expect(viewModel.controlBarModel?.isVisible == true)
        viewModel.beginScrub(itemID: item.id)

        clock.time += 10 // long past the would-be deadline
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            viewModel.controlBarModel?.isVisible == true,
            "the drag suspends the idle policy — no mid-drag hide (S3(a))"
        )

        viewModel.scrubEnded(itemID: item.id, fraction: 0.5)
        #expect(
            viewModel.controlBarModel?.isVisible == true,
            "the release restarts the countdown with the bar up (S3(a))"
        )
        clock.time += 4
        let hidden = await Self.waitFor(
            { viewModel.controlBarModel?.isVisible == false },
            "the restarted 3 s deadline must hide the bar (S3(a))"
        )
        guard hidden else { return }
    }

    /// Bar visibility (S4, S12): movement on anything but the settled
    /// current video page shows nothing — a neighbor page's id.
    @Test func mouseMovementOnNonCurrentPagesShowsNothing() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock, itemCount: 2
        )
        let neighbor = collection.items[1]

        viewModel.noteMouseMoved(itemID: neighbor.id)

        #expect(
            viewModel.controlBarModel?.isVisible == false,
            "movement on a non-current page never shows the bar (S4, S12)"
        )
    }

    /// Bar visibility (S3(b)): keyboard seek never shows the bar — the
    /// hidden model keeps its surface, the seek still lands.
    @Test func keyboardSeekNeverShowsTheBar() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, _) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)

        viewModel.seekForwardByKeyboard()

        #expect(
            handle.seeks.count == 1,
            "the seek itself lands (S2)"
        )
        #expect(
            viewModel.controlBarModel?.isVisible == false,
            "keyboard seek never shows the bar (S3(b))"
        )
    }

    /// Bar visibility (S12's premise): a paging gesture in flight drops
    /// the bar model to `nil` at once.
    @Test func pagingGestureDropsTheBarModelAtOnce() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )

        viewModel.noteMouseMoved(itemID: collection.items[0].id)
        #expect(viewModel.controlBarModel?.isVisible == true)
        viewModel.scrollGestureDidStart()

        #expect(
            viewModel.controlBarModel == nil,
            "mid-paging the model is structurally absent (S12)"
        )
        viewModel.scrollGestureDidSettle()
        #expect(
            viewModel.controlBarModel?.isVisible == false,
            "after the settle the (unchanged) video's model returns hidden (design §7)"
        )
    }

    /// Time display (§3, §8(3) — the review fix): ticks while the bar is
    /// **hidden** mutate no property the feed body reads — the model is
    /// untouched (no 10 Hz invalidation); the position store still
    /// advances, and the model rebuilds from it when the bar becomes
    /// visible.
    @Test func hiddenTicksCauseNoBarModelChangeAndVisibilityRebuilds() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        // Pipeline proof: the consumer processes ticks within a few
        // main-actor turns.
        handle.emitTick(2)
        let primed = await Self.waitFor(
            { viewModel.displayedPosition == 2 },
            "the clock consumer must be live"
        )
        guard primed else { return }

        let hiddenModel = viewModel.controlBarModel
        #expect(hiddenModel?.isVisible == false, "arrange: the bar is hidden at rest (design §7)")

        handle.emitTick(9)
        handle.emitTick(17)
        let processed = await Self.waitFor(
            { viewModel.displayedPosition == 17 },
            "the hidden ticks must still advance the position store (drift-free arithmetic)"
        )
        guard processed else { return }
        #expect(
            viewModel.controlBarModel == hiddenModel,
            "hidden ticks must not rebuild the bar model — no feed invalidation (design §8(3))"
        )

        viewModel.noteMouseMoved(itemID: item.id)
        #expect(viewModel.controlBarModel?.isVisible == true, "movement shows the bar (S3)")
        #expect(
            viewModel.controlBarModel?.elapsed == 17,
            "the visible model is rebuilt from the current position (§3)"
        )
    }

    /// Time display (§3): ticks update the displayed position and the
    /// bar model's elapsed.
    /// Time display (§3): ticks update the displayed position and — while
    /// the bar is **visible** — the bar model's elapsed.
    @Test func ticksUpdateDisplayedPositionAndTheBarModel() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.noteMouseMoved(itemID: item.id) // visible — ticks feed the model
        handle.emitTick(12.5)
        let applied = await Self.waitFor(
            { viewModel.displayedPosition == 12.5 },
            "the tick must reach the displayed position (§3)"
        )
        guard applied else { return }
        #expect(viewModel.controlBarModel?.elapsed == 12.5, "the bar's elapsed follows (§3)")
    }

    /// Time display (§3): ticks are ignored during a scrub drag — the
    /// drag target owns the display.
    @Test func ticksAreIgnoredDuringAScrubDrag() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock
        )
        let item = collection.items[0]

        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 0.5)
        handle.emitTick(10)

        #expect(
            viewModel.displayedPosition == 50,
            "a stale tick must not move the display during the drag (§3)"
        )
    }

    /// Time display (§3): ticks are suppressed for 250 ms after any
    /// `.exact` seek — a stale tick must not bounce the thumb backwards.
    @Test func ticksAreSuppressedFor250msAfterAnExactSeek() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, _) = await Self.arrangeSeekRow(handle: handle, duration: 100, clock: clock)

        // Pipeline proof: a tick lands within a few main-actor turns —
        // so the in-window drop below is a real drop, not a race.
        handle.emitTick(2)
        let primed = await Self.waitFor(
            { viewModel.displayedPosition == 2 },
            "the clock consumer must be live"
        )
        guard primed else { return }

        viewModel.seekForwardByKeyboard() // exact — 2 + 5; arms the suppression window
        #expect(viewModel.displayedPosition == 7)

        handle.emitTick(999) // inside the window
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(
            viewModel.displayedPosition == 7,
            "the stale post-commit tick is dropped (§3's 250 ms suppression)"
        )

        clock.time += 1 // past the window
        handle.emitTick(42)
        let flowed = await Self.waitFor(
            { viewModel.displayedPosition == 42 },
            "ticks flow again after the window"
        )
        guard flowed else { return }
    }

    /// Nothing carried (S15): a current-item change resets the drag
    /// machine's position state and the bar — nothing survives the page
    /// turn.
    @Test func pagingAwayResetsDragPositionAndBarState() async {
        let clock = ManualClock()
        let handle = ScriptedMediaPlayback()
        let (viewModel, _, collection) = await Self.arrangeSeekRow(
            handle: handle, duration: 100, clock: clock, itemCount: 2
        )
        let item = collection.items[0]

        viewModel.noteMouseMoved(itemID: item.id)
        viewModel.beginScrub(itemID: item.id)
        viewModel.scrubChanged(itemID: item.id, fraction: 0.42)
        #expect(viewModel.displayedPosition == 42)

        viewModel.pageForward()

        #expect(viewModel.displayedPosition == 0, "the displayed position resets (S15)")
        #expect(viewModel.controlBarModel == nil, "the departed page has no bar (S12)")
    }
}

/// The injected clock the scrub/seek rows drive (task 3's `now`): tests
/// advance it synchronously and only then yield the main actor, so the
/// generation-guarded idle task always observes a moved clock and no row
/// ever sleeps real seconds.
@MainActor
final class ManualClock {
    var time: TimeInterval = 1000
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

/// Player-seam double (E2-S3 design §10.1): a spy + scripted answerer.
/// Every `startPlayback` call is recorded; answers pop from `answers` in
/// call order (an exhausted script answers `nil` — the seam's unified
/// failure answer). With `holdingFirstCall`, the first call suspends on a
/// continuation gate until `releaseFirstCall(with:)` — the deterministic
/// supersede race. A `@MainActor final class` per the seam's isolation
/// (E2-S3 design §1.2).
@MainActor
private final class ScriptedMediaPlayerService: MediaPlayerService {
    private var answers: [MediaPlayback?]
    private let holdFirstCall: Bool
    private var firstCallGate: CheckedContinuation<MediaPlayback?, Never>?
    private(set) var calls: [MediaItem] = []

    init(answers: [MediaPlayback?] = [], holdingFirstCall: Bool = false) {
        self.answers = answers
        holdFirstCall = holdingFirstCall
    }

    /// True while the first call is suspended on the gate.
    var isHoldingFirstCall: Bool {
        firstCallGate != nil
    }

    /// Releases the suspended first call with `answer` (no-op when not
    /// held).
    func releaseFirstCall(with answer: (any MediaPlayback)?) {
        firstCallGate?.resume(returning: answer)
        firstCallGate = nil
    }

    func wiringProbe() async -> String {
        "ScriptedMediaPlayerService"
    }

    func startPlayback(for item: MediaItem) async -> MediaPlayback? {
        calls.append(item)
        if calls.count == 1, holdFirstCall {
            return await withCheckedContinuation { (continuation: CheckedContinuation<MediaPlayback?, Never>) in
                firstCallGate = continuation
            }
        }
        guard !answers.isEmpty else { return nil }
        return answers.removeFirst()
    }
}

/// Scripted session handle (E2-S3 design §10.1): records every command;
/// the test drives its events through `emit`. After `stop()` nothing is
/// emitted and the stream is finished — brace 1, exactly like the real
/// session (design §3); the view model's identity and generation braces
/// stay exercised through this honest shape.
@MainActor
private final class ScriptedMediaPlayback: MediaPlayback {
    let events: AsyncStream<MediaPlaybackEvent>
    private let continuation: AsyncStream<MediaPlaybackEvent>.Continuation

    /// Scripted duration (task 1.4's minimal member): tests overwrite it
    /// when the guard/clamp rows need a known length (task 5); the
    /// non-zero default matches the stub's canned answer shape.
    var duration: TimeInterval = 90

    /// Elapsed ticks (task 1.4's minimal member): finished on `stop()` —
    /// brace 1 parity with the real session (design §3). The task-5 suite
    /// drives ticks through it.
    let timeUpdates: AsyncStream<TimeInterval>
    private let timeUpdatesContinuation: AsyncStream<TimeInterval>.Continuation

    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var restartCount = 0
    private(set) var stopCount = 0

    /// Recorded seeks (task 1.4's minimal member): target seconds +
    /// tolerance per call, in call order — the spy record the task-5
    /// policy suite asserts against.
    private(set) var seeks: [(seconds: TimeInterval, tolerance: MediaSeekTolerance)] = []

    private(set) var isStopped = false

    init() {
        (events, continuation) = AsyncStream.makeStream(of: MediaPlaybackEvent.self)
        (timeUpdates, timeUpdatesContinuation) = AsyncStream.makeStream(of: TimeInterval.self)
    }

    /// Drives one event into the stream (the test's hand on the double).
    func emit(_ event: MediaPlaybackEvent) {
        guard !isStopped else { return }
        continuation.yield(event)
    }

    func pause() {
        guard !isStopped else { return }
        pauseCount += 1
    }

    func resume() {
        guard !isStopped else { return }
        resumeCount += 1
    }

    func restart() {
        guard !isStopped else { return }
        restartCount += 1
    }

    /// The seek spy (task 1.4's minimal member): records the call — the
    /// guard matches every other command; nothing is reflected into the
    /// tick stream (the task-5 suite drives ticks explicitly).
    func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance) {
        guard !isStopped else { return }
        seeks.append((seconds, tolerance))
    }

    /// Drives one elapsed tick into the stream (the task-5 suite's hand
    /// on the clock — `applyTick` consumes it through the view model's
    /// clock consumer).
    func emitTick(_ seconds: TimeInterval) {
        guard !isStopped else { return }
        timeUpdatesContinuation.yield(seconds)
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        stopCount += 1
        continuation.finish()
        timeUpdatesContinuation.finish()
    }

    func makeDisplayView() -> AnyObject {
        NSView()
    }
}
