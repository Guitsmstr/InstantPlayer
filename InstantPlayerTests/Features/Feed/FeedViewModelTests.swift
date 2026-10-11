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
