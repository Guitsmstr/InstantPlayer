//
//  AppDependencies.swift
//  InstantPlayer
//
//  Composition root (E1-S3, design §3.1 — R9, R13, R16).
//

/// The composition root: the ONLY place Domain protocols bind to concrete
/// implementations (R9). Hand-wired — no DI framework (story non-goal).
/// Construction cost at launch: one object allocation + two stateless
/// structs (R13 — design §6).
///
/// Binding rules (design §3.1, enforced by review and referenced from
/// `docs/architecture.md`): this is the only non-test type allowed to
/// (a) reference feature **Data** concretions and (b) construct feature
/// view models. Everything else depends on protocols.
@MainActor
final class AppDependencies {
    /// Bound seams. Feature code sees only the protocol types.
    let mediaPlayerService: any MediaPlayerService
    let mediaFolderRepository: any MediaFolderRepository

    /// Binding API: production uses the defaults (stubs today); tests and
    /// previews inject conformances through the same initializer.
    /// Allocation-only construction — no registration tables, no I/O,
    /// nothing scheduled (R13).
    init(
        mediaPlayerService: any MediaPlayerService = StubMediaPlayerService(),
        mediaFolderRepository: any MediaFolderRepository = StubMediaFolderRepository()
    ) {
        self.mediaPlayerService = mediaPlayerService
        self.mediaFolderRepository = mediaFolderRepository
    }

    /// Feature factory (R9): view models are constructed only here.
    /// Called when a feature view appears — never at launch (R13).
    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(mediaPlayerService: mediaPlayerService)
    }
}
