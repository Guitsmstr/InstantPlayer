//
//  FeedViewModel.swift
//  InstantPlayer
//
//  Feed Presentation view model — the house pattern (E1-S3, design §3.7 —
//  R3, R4; E2-S1, design §4 — S5–S7).
//

import Observation

/// The only presentation-state holder (D8): owns the `FeedState` machine,
/// routes the one entry action to the `MediaFolderRepository` seam, and
/// applies the seam's answer. `@MainActor @Observable final class` per the
/// house pattern (R3, R4).
///
/// Last-wins supersede (design §3.1, §4, §7.4): an entry action arriving
/// while a collection is in flight supersedes it — a generation counter
/// decides at completion, superseded results are dropped (no queue, no
/// re-scan of superseded work). The wiring probe UI (`probeResult`) is
/// gone; the probe lives on the seams for wiring tests (design §4).
@MainActor
@Observable
final class FeedViewModel {
    private let mediaPlayerService: any MediaPlayerService
    private let mediaFolderRepository: any MediaFolderRepository

    /// The presentation state machine — starts in the welcome state (S5).
    private(set) var state: FeedState = .welcome

    /// Monotonic entry-action generation; only the newest action's result
    /// is applied (design §3.1: last one wins).
    private var latestEntryGeneration = 0

    init(
        mediaPlayerService: any MediaPlayerService,
        mediaFolderRepository: any MediaFolderRepository
    ) {
        self.mediaPlayerService = mediaPlayerService
        self.mediaFolderRepository = mediaFolderRepository
    }

    /// Routes one entry action (S1–S4) through the seam exactly once —
    /// one repository call per action (§7.4). Media arrives →
    /// `.folderOpen(collection)` (S6: leaving welcome). No media →
    /// `.welcome` (S5 at launch; S7 mid-session — no folder stays open).
    /// A superseded action's result is discarded (§3.1, §7.4).
    func handle(entryAction: EntryAction) async {
        latestEntryGeneration += 1
        let generation = latestEntryGeneration
        let collection = await mediaFolderRepository.prepareCollection(
            forEntryAt: entryAction
        )
        guard generation == latestEntryGeneration else { return }
        if let collection {
            state = .folderOpen(collection)
        } else {
            state = .welcome
        }
    }
}
