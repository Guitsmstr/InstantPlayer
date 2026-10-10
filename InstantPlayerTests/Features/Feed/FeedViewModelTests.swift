//
//  FeedViewModelTests.swift
//  InstantPlayerTests
//
//  Feed view-model wiring + construction tests (E1-S3, design §5.2 — R16;
//  E2-S1 task 3.3 — minimal compile-level fix; the full §9 suites are task 4).
//

@testable import InstantPlayer
import Testing

/// Suites are `@MainActor`: the types under test are MainActor-isolated.
@MainActor
struct FeedViewModelTests {
    /// Case 1 — the shell view model initializes via the composition root
    /// and starts in the welcome state (S5). The end-to-end probe now lives
    /// on the seams (AppDependenciesTests case 5) after the view-model
    /// probe UI was removed (E2-S1 design §4); the full state-machine
    /// suites arrive with task 4 (design §9.2).
    @Test func shellViewModelStartsInWelcomeThroughCompositionRoot() {
        let dependencies = AppDependencies()
        let viewModel = dependencies.makeFeedViewModel()
        guard case .welcome = viewModel.state else {
            Issue.record("FeedViewModel must start in .welcome (S5)")
            return
        }
    }

    /// Case 2 — the view constructs with a view model (no rendering in
    /// unit tests).
    @Test func viewConstructsWithViewModel() {
        let dependencies = AppDependencies()
        let viewModel = dependencies.makeFeedViewModel()
        _ = FeedView(viewModel: viewModel)
    }
}
