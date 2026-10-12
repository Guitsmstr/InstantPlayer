//
//  ItemPagingBehaviorTests.swift
//  InstantPlayerTests
//
//  The paging target decision as a pure function (the D22 amendment —
//  the fullscreen wheel fix, E2-S3 review): fixed, viewport-size-
//  independent pixel and velocity thresholds. The one-item-per-gesture
//  and no-wrap semantics are the view model's settle guard (S4, S6) and
//  stay covered by `FeedViewModelTests` — this suite pins only the
//  target-picking decision (`ItemPagingBehavior.pageDirection`) and its
//  documented constants. `ScrollTarget`/`ScrollTargetBehaviorContext`
//  have no public initializers, so the behavior's grid snapping and end
//  clamping are covered through the existing index path (the settle
//  guard's clamp rows) — the brief's "clamp at ends preserved via the
//  existing index path".
//

import Foundation
@testable import InstantPlayer
import Testing

struct ItemPagingBehaviorTests {
    /// A wheel-like notch — the defect case: small displacement (a few
    /// dozen points, nowhere near a fullscreen page) carried by a
    /// system-driven impulse velocity well over the floor → advance one
    /// item in the direction of the scroll.
    @Test func wheelNotchSmallDeltaAdvances() {
        #expect(
            ItemPagingBehavior.pageDirection(displacement: 30, velocity: 500) == 1,
            "a forward wheel notch (small delta, impulse velocity) pages forward"
        )
        #expect(
            ItemPagingBehavior.pageDirection(displacement: -30, velocity: -500) == -1,
            "a backward wheel notch pages backward"
        )
    }

    /// A deliberate pull of at least the pixel floor pages on
    /// displacement alone, even at walking speed.
    @Test func deliberatePullOverThePixelFloorAdvances() {
        #expect(ItemPagingBehavior.pageDirection(displacement: 200, velocity: 0) == 1)
        #expect(ItemPagingBehavior.pageDirection(displacement: -200, velocity: 0) == -1)
    }

    /// A tiny trackpad nudge — a few points at walking speed, below both
    /// thresholds → no page; the surface's nearest-item proposal (the
    /// current item) is kept — the snap-back.
    @Test func tinyTrackpadNudgeDoesNotPage() {
        #expect(
            ItemPagingBehavior.pageDirection(displacement: 3, velocity: 20) == 0,
            "a tiny forward nudge snaps back"
        )
        #expect(
            ItemPagingBehavior.pageDirection(displacement: -3, velocity: -20) == 0,
            "a tiny backward nudge snaps back"
        )
    }

    /// A deliberate slow drag below both thresholds does not page either —
    /// the two floors separate impulses (wheel notches, flings) and
    /// deliberate pulls from slow movement.
    @Test func slowShortDragBelowTheFloorsDoesNotPage() {
        #expect(ItemPagingBehavior.pageDirection(displacement: 40, velocity: 150) == 0)
        #expect(ItemPagingBehavior.pageDirection(displacement: -40, velocity: -150) == 0)
    }

    /// Zero displacement and zero velocity is the degenerate no-page.
    @Test func zeroInputsDoNotPage() {
        #expect(ItemPagingBehavior.pageDirection(displacement: 0, velocity: 0) == 0)
    }

    /// Magnitude never compounds: a strong fling pages exactly one item,
    /// not several (the one-item-per-gesture target side; the view-model
    /// guard remains the semantic guarantee).
    @Test func strongFlingStillPagesExactlyOneItem() {
        #expect(ItemPagingBehavior.pageDirection(displacement: 800, velocity: 3000) == 1)
        #expect(ItemPagingBehavior.pageDirection(displacement: -800, velocity: -3000) == -1)
    }

    /// Both floors are inclusive — at exactly a threshold the gesture
    /// pages (decided boundaries, not fuzzy ones).
    @Test func thresholdsAreInclusive() {
        #expect(
            ItemPagingBehavior.pageDirection(displacement: ItemPagingBehavior.displacementFloor, velocity: 0) == 1
        )
        #expect(
            ItemPagingBehavior.pageDirection(displacement: -ItemPagingBehavior.displacementFloor, velocity: 0) == -1
        )
        #expect(ItemPagingBehavior.pageDirection(displacement: 0, velocity: ItemPagingBehavior.velocityFloor) == 1)
        #expect(ItemPagingBehavior.pageDirection(displacement: 0, velocity: -ItemPagingBehavior.velocityFloor) == -1)
    }

    /// The threshold constants are real, positive numbers — never zero (a
    /// zero floor would page on any nonzero input, including the tiny
    /// nudge that must snap back).
    @Test func thresholdConstantsArePositive() {
        #expect(ItemPagingBehavior.displacementFloor > 0)
        #expect(ItemPagingBehavior.velocityFloor > 0)
    }
}
