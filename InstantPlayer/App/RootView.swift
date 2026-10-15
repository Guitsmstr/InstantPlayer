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
/// E5-S1 composition (design §6.1): the root also owns the presentation
/// switch between the feed and the MediaList feature's view (S3–S5) —
/// which feature view is mounted is a root decision, so no feed contract
/// changes (S5) and the welcome surface is structurally unreachable by
/// list machinery (S16: no list model exists until a folder is open). The
/// playback session lives below the switch and survives it (§5.3 — a
/// list↔feed switch is neither a teardown point nor a revisit). The three
/// root routings: each new `MediaCollection` (the funnel is the entry
/// route's completion) is applied to the list model (S18's reset
/// funnel — a new snapshot resets the selection, the welcome fallback
/// dismisses and resets the model); row activation is mediated into the existing
/// `FeedViewModel.moveTo(itemID:)` positioning contract (S12/S13 — the
/// no-restart rule for the already-current row lives in the list model,
/// §4); the feed's current item is mirrored into the list model as the
/// read-only S17 highlight value (never a selection, design §3.3).
///
/// Launch discipline (R13, RNF-02, design §7.3): construction here is
/// allocation-only — the feed view model is one of the design's sanctioned
/// launch allocations, created via the composition-root factory; the list
/// model is created on demand with the folder-open state (§7(6) — nothing
/// new at launch); nothing scans, reads, or schedules at launch. The §3.1
/// `NSApplicationDelegateAdaptor` fallback is deliberately NOT built —
/// open-document delivery is a converge-review question (coordinator's
/// escalation, not an implementer decision).
struct RootView: View {
    let dependencies: AppDependencies

    /// The one state machine for the one window (design §3.4). Created via
    /// the factory at root construction — allocation-only (§7.3).
    @State private var viewModel: FeedViewModel

    /// The MediaList view model (E5-S1 design §6.1): created on demand with
    /// the folder-open state via the composition factory — nothing runs at
    /// launch (§7(6)). Root-owned so the switch can mount either feature
    /// view; the instance persists across switches so the selection
    /// survives them (S18 — survival is structural), and a new folder's
    /// snapshot resets the selection at `apply(collection:)`.
    @State private var listModel: MediaListViewModel?

    /// Window-drop hover state (design §3.1) — drives the welcome
    /// surface's hover affordance.
    @State private var isDropTargeted = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeFeedViewModel())
    }

    var body: some View {
        Group {
            if isListPresented, let listModel {
                MediaListView(viewModel: listModel)
            } else {
                feedSurface
            }
        }
        .onOpenURL { url in
            route(EntryAction(enteredURL: url))
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            routeDrop(providers)
            return true
        }
        .onChange(of: viewModel.currentItemID) { _, newItemID in
            // S17 — the highlight is a read-only projection of the feed's
            // current item onto the list (design §3.3): mirrored here so
            // it tracks paging, activation, and entry alike. A rendering
            // input only — the selection machine has no API for it.
            listModel?.highlightItemID = newItemID
        }
    }

    /// The presented view (S3–S5): the list only while its model says so —
    /// the same value the App-owned key monitor consults (AppDelegate,
    /// D10) — and only in the folder-open state (S16's structural gate:
    /// no list chrome is ever mounted over welcome, whatever a stale
    /// model value could carry). No model (the welcome state) ⇒ the feed
    /// surface: no list, no toggle, and no selection exist structurally
    /// in welcome (S16).
    private var isListPresented: Bool {
        guard case .folderOpen = viewModel.state else { return false }
        return listModel?.isListPresented ?? false
    }

    /// The feed surface (S5): the feed exactly as shipped, with the one
    /// on-screen toggle as a standalone floating control at the top-left
    /// of the window/feed area (S4, design §5.2 — the binding
    /// stakeholder amendment of 2026-10-14; D41: never inside the video
    /// control bar). Demand-driven on the feed's chrome demand signal —
    /// mouse movement over the settled current page of either kind
    /// (video or image; §12(7)'s sanctioned Feed-side extension) — and
    /// gone with it at the shared 3 s idle: the E2-S2 S14 idle
    /// chrome-free viewport contract is preserved. Independent of the
    /// control bar (D41): no control-bar behavior or layout change.
    private var feedSurface: some View {
        FeedView(viewModel: viewModel, isDropTargeted: isDropTargeted)
            .overlay(alignment: .topLeading) {
                if viewModel.isChromeDemanded, let listModel {
                    ViewToggleControl(viewModel: listModel)
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
            }
    }

    /// Routes one entry action through the state machine (§3.1: routed
    /// once; the @MainActor machine applies the seam's answer). The
    /// completion is the snapshot funnel (design §6.1).
    private func route(_ action: EntryAction) {
        Task {
            await viewModel.handle(entryAction: action)
            mediateListSnapshot()
        }
    }

    /// The snapshot funnel (E5-S1 design §6.1 — S18's reset funnel),
    /// run on the entry route's completion: the settled folder-open
    /// snapshot is applied to the list model (created on demand here —
    /// nothing at launch, §7(6)), the activation callback is bound to the
    /// feed's positioning contract (a pure `moveTo(itemID:)` — the model
    /// has already flipped presentation by the time it emits, and the
    /// already-current row never emits at all, §4/§5.3), and the S17
    /// highlight is seeded from the feed's current item. Re-entry with the
    /// same snapshot is a model-level no-op (S18: only a new snapshot
    /// value resets the selection). The non-`folderOpen` answer (the
    /// welcome fallback — a failed entry action, E2-S1 S7) is never a
    /// silent early return: the list model is dismissed and reset (S16 —
    /// no stale list UI over the welcome surface; S18 — no selection
    /// outlives its rows).
    private func mediateListSnapshot() {
        guard case let .folderOpen(collection) = viewModel.state else {
            // S16, S18 — welcome fallback: the rows and the selection
            // belonged to the closed folder, so the model goes with it.
            listModel?.dismissToWelcome()
            return
        }
        let model = listModel ?? dependencies.makeMediaListViewModel()
        if listModel == nil {
            listModel = model
        }
        model.onActivate = { [weak feedModel = viewModel] itemID in
            feedModel?.moveTo(itemID: itemID)
        }
        model.apply(collection: collection)
        model.highlightItemID = viewModel.currentItemID
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
