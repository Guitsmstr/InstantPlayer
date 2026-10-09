//
//  FeedViewModel.swift
//  InstantPlayer
//
//  Feed Presentation view model — the house pattern (E1-S3, design §3.7 — R3, R4).
//

import Observation

/// The house pattern: `@MainActor` + `@Observable` + `final class`.
/// View models are the only presentation-state holders (R3).
@MainActor
@Observable
final class FeedViewModel {
    private let mediaPlayerService: any MediaPlayerService
    private(set) var probeResult: String?

    init(mediaPlayerService: any MediaPlayerService) {
        self.mediaPlayerService = mediaPlayerService
    }

    /// Calls the Domain seam; Data answers through the bound conformance.
    func runWiringProbe() async {
        probeResult = await mediaPlayerService.wiringProbe()
    }
}
