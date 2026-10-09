//
//  FeedViewModelTests.swift
//  InstantPlayerTests
//
//  Feed shell wiring + construction tests (E1-S3, design §5.2 — R16).
//

@testable import InstantPlayer
import Testing

/// Suites are `@MainActor`: the types under test are MainActor-isolated.
@MainActor
struct FeedViewModelTests {
    /// Case 1 — the shell view model initializes via the composition root:
    /// `makeFeedViewModel()` → `runWiringProbe()` → the stub constant.
    /// Proves Presentation → Domain ← Data end-to-end through the binding
    /// (R1, R2, R3, R16).
    @Test func shellViewModelProbesEndToEndThroughCompositionRoot() async {
        let dependencies = AppDependencies()
        let viewModel = dependencies.makeFeedViewModel()
        await viewModel.runWiringProbe()
        #expect(viewModel.probeResult == "StubMediaPlayerService")
    }

    /// Case 2 — the view constructs with a view model (no rendering in
    /// unit tests).
    @Test func viewConstructsWithViewModel() {
        let dependencies = AppDependencies()
        let viewModel = dependencies.makeFeedViewModel()
        _ = FeedView(viewModel: viewModel)
    }
}
