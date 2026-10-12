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
/// Stateless — zero I/O (design §7). A `@MainActor final class` since the
/// E2-S3 seam is `@MainActor` + `AnyObject` (E2-S3 design §1.2, §2 —
/// class semantics for the mutable session state).
private final class ProbeMediaPlayerService: MediaPlayerService {
    func wiringProbe() async -> String {
        "InjectedProbeService"
    }

    /// This double exists only for the wiring probes (case 4/5) — the
    /// session member is a canned `nil`, never called by those tests.
    func startPlayback(for _: MediaItem) async -> MediaPlayback? {
        nil
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

    /// Case 3 — filesystem-seam binding resolves to the real
    /// security-scoped actor (E2-S1 design §1; R7, R9, R16 — the stub
    /// remains available for explicit injection).
    @Test func filesystemSeamBindingResolvesToSecurityScopedRepository() {
        let dependencies = AppDependencies()
        #expect(dependencies.mediaFolderRepository is SecurityScopedMediaFolderRepository)
    }

    /// Case 4 — the binding API accepts injection: a test-local
    /// conformance passed to the initializer is what gets bound (and what
    /// the factory hands the view model). The probe lives on the seams
    /// since the view-model probe UI was removed (E2-S1 design §4).
    @Test func bindingAPIAcceptsInjection() async {
        let dependencies = AppDependencies(mediaPlayerService: ProbeMediaPlayerService())
        #expect(await dependencies.mediaPlayerService.wiringProbe() == "InjectedProbeService")
    }

    /// Case 5 — behavioral end-to-end: the player stub answers with its
    /// constant; the folder repository actor answers with its own (R16;
    /// the probe stays on the seams after the view-model probe UI was
    /// removed in E2-S1).
    @Test func stubProbesAnswerWithConstants() async {
        let dependencies = AppDependencies()
        #expect(await dependencies.mediaPlayerService.wiringProbe() == "StubMediaPlayerService")
        #expect(
            await dependencies.mediaFolderRepository.wiringProbe()
                == "SecurityScopedMediaFolderRepository"
        )
    }

    /// Case 6 — the factory records the produced model on the container for
    /// the arrow-key monitor (E2-S2 round 4 — evidence §8): the recorded
    /// instance IS the returned one (identity).
    @Test func factoryRecordsTheActiveFeedModel() {
        let dependencies = AppDependencies()
        let model = dependencies.makeFeedViewModel()
        #expect(dependencies.activeFeedModel === model)
    }

    /// Case 7 — registration is record-once: the first factory call is the
    /// instance `RootView`'s `@State` keeps (`State(initialValue:)` ignores
    /// later values), so later transient factory calls (SwiftUI body
    /// re-evaluations) must not steal the registration (E2-S2 round 4 —
    /// evidence §8).
    @Test func factoryRegistrationIsRecordOnce() {
        let dependencies = AppDependencies()
        let first = dependencies.makeFeedViewModel()
        _ = dependencies.makeFeedViewModel()
        #expect(dependencies.activeFeedModel === first)
    }
}
