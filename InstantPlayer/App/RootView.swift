//
//  RootView.swift
//  InstantPlayer
//
//  App-owned root view (E1-S3, design §3.3 — R9, R13; E2-S1, design §3.1 —
//  S1–S4 entry routing).
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// App-owned root: hosts `FeedView` and converts the system's entry events
/// into `EntryAction`s (design §3.1). `.onOpenURL` carries Finder
/// "Open With" and Dock-icon drops (the open-document event); `.onDrop`
/// carries window drops (`UTType.fileURL` providers). Every channel
/// converges on the single `EntryAction` value, routed once to
/// `FeedViewModel.handle(entryAction:)`; a multi-item gesture is N actions
/// in event order, last one wins (§3.1). No queue, no re-scan (§7.4).
///
/// Launch discipline (R13, RNF-02, design §7.3): construction here is
/// allocation-only — the view model is one of the design's two sanctioned
/// launch allocations, created via the composition-root factory; nothing
/// scans, reads, or schedules at launch. The §3.1
/// `NSApplicationDelegateAdaptor` fallback is deliberately NOT built —
/// open-document delivery is a converge-review question (coordinator's
/// escalation, not an implementer decision).
struct RootView: View {
    let dependencies: AppDependencies

    /// The one state machine for the one window (design §3.4). Created via
    /// the factory at root construction — allocation-only (§7.3).
    @State private var viewModel: FeedViewModel

    /// Window-drop hover state (design §3.1) — drives the welcome
    /// surface's hover affordance.
    @State private var isDropTargeted = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeFeedViewModel())
    }

    var body: some View {
        FeedView(viewModel: viewModel, isDropTargeted: isDropTargeted)
            .onOpenURL { url in
                route(EntryAction(enteredURL: url))
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                routeDrop(providers)
                return true
            }
    }

    /// Routes one entry action through the state machine (§3.1: routed
    /// once; the @MainActor machine applies the seam's answer).
    private func route(_ action: EntryAction) {
        Task { await viewModel.handle(entryAction: action) }
    }

    /// Converts one window drop into N ordered entry actions (§3.1: N
    /// actions in event order, last wins). Only file-URL providers are
    /// loaded; anything else is ignored — the seam validates file URLs at
    /// the Data edge (§8.3) and answers with welcome.
    private func routeDrop(_ providers: [NSItemProvider]) {
        Task {
            for provider in providers {
                if let url = try? await loadURL(from: provider) {
                    route(EntryAction(enteredURL: url))
                }
            }
        }
    }

    /// Bridges the item provider's callback API into async/await (house
    /// rule: async/await only, no completion handlers of our own —
    /// architecture §5).
    private func loadURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let object {
                    continuation.resume(returning: object)
                } else {
                    continuation.resume(
                        throwing: error ?? CocoaError(.featureUnsupported)
                    )
                }
            }
        }
    }
}
