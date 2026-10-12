//
//  ArrowKeyCommandTests.swift
//  InstantPlayerTests
//
//  Arrow-key routing decision tests (E2-S2 round 4 — evidence §8 — S5).
//

import AppKit
@testable import InstantPlayer
import Testing

/// Suites are `@MainActor`: the types under test are MainActor-isolated
/// (house pattern, `AppDependenciesTests`). The decision table is pure —
/// no `NSEvent` instances, no UI (design §10.1 pattern). Key codes are
/// the hardware `NSEvent.keyCode` values: 125 = ↓, 126 = ↑, 123 = ←,
/// 124 = →, 0 = A — pinned here so the table cannot drift from the
/// hardware.
@MainActor
struct ArrowKeyCommandTests {
    /// Plain ↓ with a feed open → page forward (S5).
    @Test func plainDownArrowPagesForwardWhenFeedIsOpen() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                hasOpenFeed: true
            ) == .pageForward
        )
    }

    /// Plain ↑ with a feed open → page backward (S5).
    @Test func plainUpArrowPagesBackwardWhenFeedIsOpen() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Welcome state: every key passes through, arrows included (S16 —
    /// no paging presented outside the feed).
    @Test func welcomePassesArrowsThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    /// ⌘-modified arrows pass through — system shortcuts are never ours
    /// (evidence §8, round 4: the pass-through guard).
    @Test func commandModifiedArrowsPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [.command],
                hasOpenFeed: true
            ) == .passThrough
        )
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [.command],
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⌥-modified arrows pass through.
    @Test func optionModifiedArrowsPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [.option],
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⌃-modified arrows pass through.
    @Test func controlModifiedArrowsPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [.control],
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// Combined ⌘⌥⌃ passes through (any command modifier is enough).
    @Test func combinedCommandModifiersPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [.command, .option, .control],
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⇧ alone is not a command modifier — ⇧↓/⇧↑ page, like the unmodified
    /// keys (documented decision, evidence §8 round 4).
    @Test func shiftAloneStillPages() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [.shift],
                hasOpenFeed: true
            ) == .pageForward
        )
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [.shift],
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Real arrow keyDown events carry `.function` and `.numericPad` —
    /// those flags are not command modifiers and must still page. This is
    /// the regression pin against treating "any modifier" as pass-through.
    @Test func systemArrowFlagsStillPage() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 125,
                modifiers: [.function, .numericPad],
                hasOpenFeed: true
            ) == .pageForward
        )
        #expect(
            ArrowKeyCommand.route(
                keyCode: 126,
                modifiers: [.function, .numericPad],
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Non-routed arrow keys pass through (←/→ are not feed commands in
    /// this story; the vertical feed pages on ↓/↑ only — S5).
    @Test func nonRoutedArrowsPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                hasOpenFeed: true
            ) == .passThrough
        )
        #expect(
            ArrowKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// Plain character keys (here: key code 0, the A key) pass through —
    /// typing and future text input are never intercepted (evidence §8,
    /// round 4).
    @Test func nonArrowKeysPassThrough() {
        #expect(
            ArrowKeyCommand.route(
                keyCode: 0,
                modifiers: [],
                hasOpenFeed: true
            ) == .passThrough
        )
    }
}
