//
//  FeedView.swift
//  InstantPlayer
//
//  Feed Presentation view — a dumb binder (E1-S3, design §3.8 — R3;
//  E2-S1, design §4 — S5–S7; E2-S2, design §2, §5.1–§5.3 — S1, S2,
//  S4–S6, S10, S11, S14).
//

import SwiftUI

/// Dumb binder: renders `WelcomeView` for `.welcome` (S16 — untouched,
/// its accessibility identifier keeps the launch UI tests green) and, for
/// `.folderOpen`, the vertical paging feed (design §5.1): one `ScrollView`
/// + `LazyVStack` over the collection's snapshot order (S1 — never
/// sorted; the interim placeholder is replaced outright), each page
/// exactly the viewport via `.containerRelativeFrame` (S2 — which is also
/// the whole resize/fullscreen story, S10/S11: container-derived layout,
/// no special-case code exists), magnetic snap via
/// `.scrollTargetBehavior(.paging)` (S4 — the resting state is always one
/// full item), the two-way `scrollPosition(id:)` binding projected onto
/// the view model (design §5.1, §1.1 — never view state), scroll-phase
/// signals feeding the view model's gesture guard (§5.2), and arrow-key
/// paging (§5.3). Chrome-free (S14): hidden scroll indicators, no
/// overlays of any kind. No state of its own, no Data imports (R2), no
/// I/O in `body` (RNF-02).
struct FeedView: View {
    let viewModel: FeedViewModel

    /// Window-drop hover state owned by `RootView` (design §3.1); drives
    /// the welcome surface's hover affordance.
    var isDropTargeted: Bool = false

    var body: some View {
        switch viewModel.state {
        case .welcome:
            WelcomeView(isTargeted: isDropTargeted)
        case let .folderOpen(collection):
            feed(collection)
        }
    }

    // MARK: The paging feed (design §5.1–§5.3)

    private func feed(_ collection: MediaCollection) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(collection.items) { item in
                    FeedItemView(displayState: viewModel.displayStates[item.id])
                        // The page IS the viewport (design §5.1) — resize
                        // and native fullscreen re-fill it with no code
                        // (S10, S11).
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: scrollPosition)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .onScrollPhaseChange { oldPhase, newPhase in
            if newPhase == .idle {
                if oldPhase != .idle {
                    // Settle (design §5.2 step 2): the scroll returned to
                    // rest — run the guard.
                    viewModel.scrollGestureDidSettle()
                }
            } else if oldPhase == .idle || newPhase == .tracking {
                // Onset (step 1: the scroll left rest). A re-touch during
                // deceleration re-records from the then-visible index
                // (step 3).
                viewModel.scrollGestureDidStart()
            }
        }
        .onKeyPress(.downArrow) {
            viewModel.pageForward()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.pageBackward()
            return .handled
        }
        // Key delivery (design §5.3): `onKeyPress` fires on the focused
        // view — the feed is the one focusable surface, with the focus
        // ring suppressed to keep the viewport chrome-free (S14).
        .focusable()
        .focusEffectDisabled()
    }

    /// The two-way `scrollPosition(id:)` binding (design §5.1, §1.1): a
    /// projection of view-model state — the read side is the current
    /// item's identity, the write side routes through the state machine
    /// (`moveTo(itemID:)`).
    private var scrollPosition: Binding<URL?> {
        Binding(
            get: { viewModel.currentItemID },
            set: { viewModel.moveTo(itemID: $0) }
        )
    }
}
