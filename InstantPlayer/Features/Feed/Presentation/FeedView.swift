//
//  FeedView.swift
//  InstantPlayer
//
//  Feed Presentation view — a dumb binder (E1-S3, design §3.8 — R3;
//  E2-S1, design §4 — S5–S7; E2-S2, design §2, §5.1–§5.3 — S1, S2,
//  S4–S6, S10, S11, S14; E3-S1, design §7 — S1, S3, S5, S11: the bar
//  model + actions drill).
//

import SwiftUI

/// Dumb binder: renders `WelcomeView` for `.welcome` (S16 — untouched,
/// its accessibility identifier keeps the launch UI tests green) and, for
/// `.folderOpen`, the vertical paging feed (design §5.1): one `ScrollView`
/// + `LazyVStack` over the collection's snapshot order (S1 — never
/// sorted; the interim placeholder is replaced outright), each page
/// exactly the viewport via `.containerRelativeFrame` (S2 — which is also
/// the whole resize/fullscreen story, S10/S11: container-derived layout,
/// no special-case code exists), the paging target behavior
/// `ItemPagingBehavior` (S4 — the resting state is always one full item;
/// viewport-size-independent thresholds — the D22 amendment, the
/// fullscreen wheel fix), the two-way `scrollPosition(id:)` binding
/// projected onto the view model (design §5.1, §1.1 — never view state),
/// scroll-phase signals feeding the view model's gesture guard (§5.2).
/// Feed-key delivery (§5.3 as shipped — evidence §8) is App-owned: an
/// `NSEvent` local monitor (AppDelegate) routes ↓/↑ and space into the
/// view model's paging/toggle methods, so this binder carries no key or
/// focus handling of any kind. The click toggle (E2-S3 design §6 — S6,
/// S7) is a plain SwiftUI tap: `FeedView` drills one `onTap` closure per
/// page (capturing the item id) into the guarded
/// `togglePlaybackFromTap(itemID:)` — taps are not focus-dependent (the
/// evidence §8 failure was key focus), and no App-level mouse monitor
/// exists. E3-S1 (design §7) drills the same way: each page receives its
/// own `PlaybackControlBarModel?` (the view model's value gated to the
/// page — structurally absent on every other page, S4/S12) and an
/// actions value whose closures capture the item id into the view
/// model's §5 entry points. No App-level mouse monitor (D28), no focus
/// handling. No state of its own, no Data imports (R2), no I/O in `body`
/// (RNF-02 — the behavior's id map is one O(n) pass over the same
/// snapshot `ForEach` already iterates).
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
                    FeedItemView(
                        displayState: viewModel.displayStates[item.id],
                        // The page's id (E3-S1 design §4): the mouse-move
                        // tracking area reports it.
                        itemID: item.id,
                        // The per-page tap (E2-S3 design §6): the closure
                        // captures the item id — the cell itself never
                        // sees the item (S14's structural absence); the
                        // guard matrix lives in the view model (S7).
                        onTap: { viewModel.togglePlaybackFromTap(itemID: item.id) },
                        // The per-page bar model (E3-S1 design §7): the
                        // view model builds it for the settled current
                        // video only — gated here so a neighbor cell can
                        // never render the current page's strip (S4, S12).
                        controlBarModel: item.id == viewModel.currentItemID
                            ? viewModel.controlBarModel
                            : nil,
                        // The per-page actions (E3-S1 design §7): each
                        // closure captures the item id and routes into
                        // the view model's guarded §5 entry points —
                        // ineligible states consume and no-op quietly
                        // (S12, D28).
                        actions: FeedPageActions(
                            scrubBegan: { viewModel.beginScrub(itemID: item.id) },
                            scrubChanged: { viewModel.scrubChanged(itemID: item.id, fraction: $0) },
                            scrubEnded: { viewModel.scrubEnded(itemID: item.id, fraction: $0) },
                            trackClick: { viewModel.seekFromTrackClick(itemID: item.id, fraction: $0) },
                            mouseMoved: { viewModel.noteMouseMoved(itemID: item.id) }
                        )
                    )
                    // The page IS the viewport (design §5.1) — resize
                    // and native fullscreen re-fill it with no code
                    // (S10, S11).
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: scrollPosition)
        .scrollTargetBehavior(
            // The D22 amendment (the fullscreen wheel fix): a
            // viewport-size-independent target decision — `.paging`'s
            // snap threshold scales with page height, so a wheel notch's
            // fixed delta never crossed a fullscreen-height page (S4
            // violated at large viewports). The one-item-per-gesture and
            // no-wrap semantics still rest on the view model's settle
            // guard (S4, S6 — untouched).
            ItemPagingBehavior(
                itemIDs: collection.items.map(\.id),
                currentIndex: viewModel.currentIndex
            )
        )
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

/// The feed's paging target behavior (the D22 amendment — the fullscreen
/// wheel fix, E2-S3 review): picks the rect one scroll gesture rests on
/// with a **viewport-size-independent** decision. `.paging`'s snap
/// threshold scales with page height, so a wheel notch's fixed delta is a
/// tiny fraction of a fullscreen-height page and never crosses it — in
/// native fullscreen the wheel needed many rotations to page (S4 violated
/// at large viewports). The decision here is the pure, fixed-threshold
/// `pageDirection(displacement:velocity:)`; the magnetic one-item-per-
/// gesture and no-wrap guarantees STILL rest on the view model's settle
/// guard (S4, S6 — frozen semantics, unchanged): this type only picks the
/// target. Sign convention (the single place it is decided): positive
/// displacement/velocity reads as scrolling toward later content (the
/// next item) — content y grows with the snapshot order.
struct ItemPagingBehavior: ScrollTargetBehavior {
    /// The snapshot-order item ids — the behavior snaps the target rect
    /// onto this grid, so the resting state is always one full item (S4).
    let itemIDs: [MediaItem.ID]

    /// The view model's current index as of the render that carried this
    /// instance — the one-item-per-gesture anchor: at most one item from
    /// the live current position, clamped, no wrap (S4, S6). Fresh enough
    /// because the feed re-renders on every current-item change (the
    /// `scrollPosition` binding is a view-model projection, design §5.1);
    /// the settle guard backstops any staleness.
    let currentIndex: Int?

    /// The displacement floor in points — the documented pixel constant
    /// of the D22 amendment: a deliberate pull of at least this fixed
    /// distance pages, at any viewport size. Fixed points, deliberately
    /// NOT a fraction of the page height — that proportionality is
    /// exactly what broke `.paging` at fullscreen sizes.
    nonisolated static let displacementFloor: CGFloat = 120

    /// The impulse floor in points per second — the documented velocity
    /// constant of the D22 amendment, chosen between the input bands by
    /// analysis (stakeholder retest confirms): a tiny slow trackpad nudge
    /// measures far below it (≲ 50 pt/s at a few points of
    /// displacement), a deliberate slow drag stays under it too, while a
    /// mechanical wheel notch — a small system-driven impulse: little
    /// displacement, high velocity — and a deliberate fling arrive well
    /// above it (≳ 400 pt/s). Never zero: the nudge must still snap back.
    nonisolated static let velocityFloor: CGFloat = 200

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // Each page IS the viewport (`.containerRelativeFrame`), so the
        // page height is the container height — used only to translate
        // between rect space and item space; the decision thresholds are
        // fixed points that never scale with it (the D22 amendment).
        let pageHeight = context.containerSize.height
        guard pageHeight > 0, !itemIDs.isEmpty, let current = currentIndex else { return }
        let displacement = target.rect.minY - CGFloat(current) * pageHeight
        let direction = Self.pageDirection(
            displacement: displacement,
            velocity: context.velocity.dy
        )
        let destination: Int
        if direction != 0 {
            // The gesture pages: exactly one item from the current
            // position, clamped at the ends — no wrap (S4, S6). A
            // stronger fling pages one item, not several — the magnitude
            // never compounds.
            destination = min(max(current + direction, 0), itemIDs.count - 1)
        } else {
            // Sub-threshold: keep the surface's own nearest-item
            // proposal — a tiny nudge snaps back (S4's zero-net case).
            let proposed = Int((target.rect.minY / pageHeight).rounded())
            destination = min(max(proposed, 0), itemIDs.count - 1)
        }
        // Snap the rest point onto the item grid — the resting state is
        // always one full item (S4).
        target.rect.origin.y = CGFloat(destination) * pageHeight
    }

    /// The pure, unit-testable paging decision (the D22 amendment): a
    /// displacement at or over the pixel floor (a deliberate pull) or a
    /// velocity at or over the impulse floor (a wheel notch's small-but-
    /// fast delta, or a fling) pages exactly one item in that direction;
    /// below both thresholds the gesture pages nothing and the caller
    /// keeps the surface's nearest-item proposal (the snap-back). Fixed
    /// points and points-per-second — viewport-size-independent.
    nonisolated static func pageDirection(displacement: CGFloat, velocity: CGFloat) -> Int {
        if displacement >= displacementFloor {
            return 1
        }
        if displacement <= -displacementFloor {
            return -1
        }
        if velocity >= velocityFloor {
            return 1
        }
        if velocity <= -velocityFloor {
            return -1
        }
        return 0
    }
}
