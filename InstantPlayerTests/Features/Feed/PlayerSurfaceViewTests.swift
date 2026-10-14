//
//  PlayerSurfaceViewTests.swift
//  InstantPlayerTests
//
//  The tracking-area handler selector pin (E3-S1 — the functional-review
//  defect: plain selector synthesis on an `NSObject` landed
//  `mouseMovedWith:`, which `NSTrackingArea` never sends).
//

import AppKit
@testable import InstantPlayer
import Testing

/// The `PlayerSurfaceView.Coordinator`'s tracking-area contract, pinned
/// at the Objective-C runtime level (unit-level: no UI, no window): the
/// coordinator must **respond to the selector AppKit actually dispatches**
/// — `mouseMoved:` — and invoking it must forward the page's item id to
/// the sink. With the pre-fix synthesis (`mouseMovedWith:`) the respond
/// assertion fails and nothing is ever delivered.
@MainActor
struct PlayerSurfaceViewTests {
    /// The selector `NSTrackingArea` dispatches to its owner for
    /// `.mouseMoved` (the `NSResponder` declaration's selector).
    private static let mouseMovedSelector = Selector(("mouseMoved:"))

    /// Builds one real mouse-moved event (no window required).
    private func makeMouseMovedEvent() throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            )
        )
    }

    /// The pin: the owner responds to `mouseMoved:` — fails with the
    /// pre-fix synthesis, which exposed only `mouseMovedWith:`.
    @Test func coordinatorRespondsToTheTrackingAreaSelector() {
        let coordinator = PlayerSurfaceView.Coordinator(
            itemID: nil,
            onMouseMoved: { _ in }
        )
        #expect(
            coordinator.responds(to: Self.mouseMovedSelector),
            "the tracking-area owner must respond to `mouseMoved:` — the selector AppKit dispatches"
        )
    }

    /// Dispatching `mouseMoved:` through the runtime forwards the page's
    /// item id to the sink — the exact path a tracking-area delivery
    /// takes.
    @Test func invokingMouseMovedForwardsTheItemIDToTheSink() throws {
        let sink = MouseMovedSink()
        let itemID = URL(fileURLWithPath: "/tmp/clip.mp4")
        let coordinator = PlayerSurfaceView.Coordinator(
            itemID: itemID,
            onMouseMoved: { sink.itemID = $0 }
        )
        // Guarded so the wrong-selector regression fails cleanly (a
        // recorded issue) instead of `perform`-ing an unrecognized
        // selector and crashing the runner.
        try #require(
            coordinator.responds(to: Self.mouseMovedSelector),
            "the owner must respond to the tracking-area selector before dispatch"
        )

        let event = try makeMouseMovedEvent()
        _ = coordinator.perform(Self.mouseMovedSelector, with: event)

        #expect(sink.itemID == itemID, "the dispatched mouseMoved forwards the page's item id")
    }

    /// Unwired movement (no item id drilled) reports nothing — task 6's
    /// contract, pinned at the same dispatch level.
    @Test func invokingMouseMovedWithoutAnItemIDIsAQuietNoOp() throws {
        var calls = 0
        let coordinator = PlayerSurfaceView.Coordinator(
            itemID: nil,
            onMouseMoved: { _ in calls += 1 }
        )
        try #require(
            coordinator.responds(to: Self.mouseMovedSelector),
            "the owner must respond to the tracking-area selector before dispatch"
        )

        let event = try makeMouseMovedEvent()
        _ = coordinator.perform(Self.mouseMovedSelector, with: event)

        #expect(calls == 0, "unwired movement reports nothing")
    }
}

/// The sink the selector-invocation rows assert against.
@MainActor
private final class MouseMovedSink {
    var itemID: URL?
}
