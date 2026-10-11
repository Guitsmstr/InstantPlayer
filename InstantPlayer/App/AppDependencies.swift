//
//  AppDependencies.swift
//  InstantPlayer
//
//  Composition root (E1-S3, design §3.1 — R9, R13, R16; E2-S1, design §1 —
//  seam binding, §7.3 allocation-only init).
//

/// The composition root: the ONLY place Domain protocols bind to concrete
/// implementations (R9). Hand-wired — no DI framework (story non-goal).
///
/// Binding rules (design §3.1, enforced by review and referenced from
/// `docs/architecture.md`): this is the only non-test type allowed to
/// (a) reference feature **Data** concretions and (b) construct feature
/// view models. Everything else depends on protocols.
///
/// Launch cost (R13, E2-S1 design §7.3): allocation-only — exactly three
/// sanctioned allocations on the launch path: the repository actor and the
/// preview actor bound here (E2-S2 adds the preview binding — design §1,
/// §8(5): one more binding allocation, nothing scheduled, no media touched
/// at launch), and the `FeedViewModel` when `RootView` appears via the
/// factory. No I/O, nothing scheduled, no scan at launch.
@MainActor
final class AppDependencies {
    /// Bound seams. Feature code sees only the protocol types.
    let mediaPlayerService: any MediaPlayerService
    let mediaFolderRepository: any MediaFolderRepository
    let mediaPreviewService: any MediaPreviewService

    /// Binding API: production uses the defaults; tests and previews inject
    /// conformances through the same initializer. The default folder seam
    /// is the real security-scoped actor (E2-S1 design §1); the default
    /// preview seam is the real extraction actor (E2-S2 design §1); the
    /// player seam stays stubbed until E2-S3.
    init(
        mediaPlayerService: any MediaPlayerService = StubMediaPlayerService(),
        mediaFolderRepository: any MediaFolderRepository = SecurityScopedMediaFolderRepository(),
        mediaPreviewService: any MediaPreviewService = AVMediaPreviewService()
    ) {
        self.mediaPlayerService = mediaPlayerService
        self.mediaFolderRepository = mediaFolderRepository
        self.mediaPreviewService = mediaPreviewService
    }

    /// Feature factory (R9): view models are constructed only here, with
    /// the bound seams (E2-S1 design §1; E2-S2 design §1 — all three seams
    /// pass through, tests inject conformances via the initializer).
    /// Called on demand — by `RootView` (design §7.3), never at app init.
    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(
            mediaPlayerService: mediaPlayerService,
            mediaFolderRepository: mediaFolderRepository,
            mediaPreviewService: mediaPreviewService
        )
    }
}
