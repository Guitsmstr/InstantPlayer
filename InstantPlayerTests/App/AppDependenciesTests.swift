//
//  AppDependenciesTests.swift
//  InstantPlayerTests
//
//  Composition-root wiring tests (E1-S3, design §5.1 — R16).
//

@testable import InstantPlayer
import Testing

/// Test-local conformance for case 4: the injected probe service whose
/// constant must flow through the binding into the produced view model.
/// Stateless — zero I/O (design §7).
private struct ProbeMediaPlayerService: MediaPlayerService {
    func wiringProbe() async -> String {
        "InjectedProbeService"
    }
}

/// Suites are `@MainActor`: the types under test are MainActor-isolated.
@MainActor
struct AppDependenciesTests {
    /// Case 1 — the default dependency graph constructs (R9, R16).
    /// Constructing without trapping IS the assertion; the dedicated
    /// binding tests below assert what got bound.
    @Test func defaultDependencyGraphConstructs() {
        _ = AppDependencies()
    }

    /// Case 2 — player-seam binding resolves to the stub (R2, R9, R16).
    @Test func playerSeamBindingResolvesToStub() {
        let dependencies = AppDependencies()
        #expect(dependencies.mediaPlayerService is StubMediaPlayerService)
    }

    /// Case 3 — filesystem-seam binding resolves to the stub (R7, R9, R16).
    @Test func filesystemSeamBindingResolvesToStub() {
        let dependencies = AppDependencies()
        #expect(dependencies.mediaFolderRepository is StubMediaFolderRepository)
    }

    /// Case 4 — the binding API accepts injection: a test-local
    /// conformance passed to the initializer is what `makeFeedViewModel()`
    /// uses, and its probe value flows through. This is also the
    /// seam-swapping pattern future security/performance tests reuse
    /// (design §5.1 item 4, §7).
    @Test func bindingAPIAcceptsInjection() async {
        let dependencies = AppDependencies(mediaPlayerService: ProbeMediaPlayerService())
        let viewModel = dependencies.makeFeedViewModel()
        await viewModel.runWiringProbe()
        #expect(viewModel.probeResult == "InjectedProbeService")
    }

    /// Case 5 — behavioral end-to-end: both stub probes answer with their
    /// constants (R16).
    @Test func stubProbesAnswerWithConstants() async {
        let dependencies = AppDependencies()
        #expect(await dependencies.mediaPlayerService.wiringProbe() == "StubMediaPlayerService")
        #expect(await dependencies.mediaFolderRepository.wiringProbe() == "StubMediaFolderRepository")
    }
}
