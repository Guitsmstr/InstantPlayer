//
//  FeedKeyCommandTests.swift
//  InstantPlayerTests
//
//  Feed-key routing decision tests (E2-S2 round 4 — evidence §8 — S5;
//  E2-S3 design §6 — space toggle).
//

import AppKit
@testable import InstantPlayer
import Testing

/// Suites are `@MainActor`: the types under test are MainActor-isolated
/// (house pattern, `AppDependenciesTests`). The decision table is pure —
/// no `NSEvent` instances, no UI (design §10.1 pattern). Key codes are
/// the hardware `NSEvent.keyCode` values: 125 = ↓, 126 = ↑, 123 = ←,
/// 124 = →, 49 = space, 33 = `[`, 30 = `]`, 0 = A — pinned here so the
/// table cannot drift from the hardware.
@MainActor
struct FeedKeyCommandTests {
    /// Plain ↓ with a feed open → page forward (S5).
    @Test func plainDownArrowPagesForwardWhenFeedIsOpen() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageForward
        )
    }

    /// Plain ↑ with a feed open → page backward (S5).
    @Test func plainUpArrowPagesBackwardWhenFeedIsOpen() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Welcome state: every key passes through, arrows included (S16 —
    /// no paging presented outside the feed).
    @Test func welcomePassesArrowsThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    /// ⌘-modified arrows pass through — system shortcuts are never ours
    /// (evidence §8, round 4: the pass-through guard).
    @Test func commandModifiedArrowsPassThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.command],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.command],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⌥-modified arrows pass through.
    @Test func optionModifiedArrowsPassThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.option],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⌃-modified arrows pass through.
    @Test func controlModifiedArrowsPassThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.control],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// Combined ⌘⌥⌃ passes through (any command modifier is enough).
    @Test func combinedCommandModifiersPassThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.command, .option, .control],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    /// ⇧ alone is not a command modifier — ⇧↓/⇧↑ page, like the unmodified
    /// keys (documented decision, evidence §8 round 4).
    @Test func shiftAloneStillPages() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageForward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Real arrow keyDown events carry `.function` and `.numericPad` —
    /// those flags are not command modifiers and must still page. This is
    /// the regression pin against treating "any modifier" as pass-through.
    @Test func systemArrowFlagsStillPage() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageForward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    /// Seek keys with a feed open (E3-S1 design §6 — S2; the recorded
    /// contract change: ←/→ 123/124 previously passed through —
    /// `nonRoutedArrowsPassThrough` is replaced by these rows): plain ←
    /// seeks backward, plain → seeks forward.
    @Test func plainLeftRightArrowsSeekWhenFeedIsOpen() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekBackward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekForward
        )
    }

    /// Seek auto-repeat = repeated steps (S9 — paging's repeat parity,
    /// `arrowAutoRepeatStillPages`'s sibling): a held ←/→ steps once per
    /// keyDown.
    @Test func seekAutoRepeatStillSteps() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .seekBackward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .seekForward
        )
    }

    /// ⇧ alone is not a command modifier for the seek keys either —
    /// ⇧←/⇧→ seek, like ⇧↓ paging (the documented decision).
    @Test func shiftAloneStillSeeks() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekBackward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekForward
        )
    }

    /// Real seek keyDown events carry `.function`/`.numericPad` — those
    /// flags are not command modifiers and must still seek (the
    /// arrow-flags regression pin's seek counterpart).
    @Test func systemSeekFlagsStillSeek() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekBackward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .seekForward
        )
    }

    /// ⌘/⌥/⌃-modified seek keys pass through — system shortcuts are
    /// never robbed (design §6's seek rows, the paging modifier columns).
    @Test func commandModifiedSeekKeysPassThrough() {
        let commandModifiers: [NSEvent.ModifierFlags] = [
            [.command],
            [.option],
            [.control],
            [.command, .option, .control],
        ]
        for modifiers in commandModifiers {
            #expect(
                FeedKeyCommand.route(
                    keyCode: 123,
                    modifiers: modifiers,
                    isRepeat: false,
                    hasOpenFeed: true
                ) == .passThrough
            )
            #expect(
                FeedKeyCommand.route(
                    keyCode: 124,
                    modifiers: modifiers,
                    isRepeat: false,
                    hasOpenFeed: true
                ) == .passThrough
            )
        }
    }

    /// Welcome: the seek keys pass through like every key — no feed, no
    /// feed commands (S16; design §6's seek rows' no-feed column).
    @Test func welcomePassesSeekKeysThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    /// Plain character keys (here: key code 0, the A key) pass through —
    /// typing and future text input are never intercepted (evidence §8,
    /// round 4).
    @Test func nonArrowKeysPassThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 0,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .passThrough
        )
    }

    // MARK: Space routing (E2-S3 design §6 — S5; tasks.md 7.4 matrix)

    /// Space (keyCode 49), first press, feed open → toggle playback (S5).
    @Test func spaceFirstPressToggles() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .togglePlayback
        )
    }

    /// Space auto-repeat is consumed and ignored — a held space must never
    /// flap play/pause (design §6; unlike arrows, where auto-repeat pages).
    @Test func spaceAutoRepeatIsConsumedAndIgnored() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .ignore
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [.shift],
                isRepeat: true,
                hasOpenFeed: true
            ) == .ignore
        )
    }

    /// ⇧ is not a command modifier — ⇧space toggles, like ⇧↓ pages
    /// (documented decision, design §6).
    @Test func shiftSpaceToggles() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .togglePlayback
        )
    }

    /// Real space keyDown events can carry system flags — those are not
    /// command modifiers and must still toggle (the arrow-flags
    /// regression pin's space counterpart).
    @Test func systemSpaceFlagsStillToggle() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .togglePlayback
        )
    }

    /// ⌘/⌥/⌃-modified space passes through — system shortcuts are never
    /// robbed (design §6; ⌃space alone is the input-source shortcut).
    @Test func commandModifiedSpacePassesThrough() {
        let commandModifiers: [NSEvent.ModifierFlags] = [
            [.command],
            [.option],
            [.control],
            [.command, .option, .control],
        ]
        for modifiers in commandModifiers {
            #expect(
                FeedKeyCommand.route(
                    keyCode: 49,
                    modifiers: modifiers,
                    isRepeat: false,
                    hasOpenFeed: true
                ) == .passThrough
            )
        }
    }

    /// Welcome: space passes through like every key — no feed, no feed
    /// commands (S16).
    @Test func welcomePassesSpaceThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [.shift],
                isRepeat: true,
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    /// Arrow auto-repeat still pages — repeated presses are the carried,
    /// accepted arrow behavior (design §6); only space repeats are
    /// consumed and ignored.
    @Test func arrowAutoRepeatStillPages() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .pageForward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .pageBackward
        )
    }

    // MARK: Speed routing (E3-S2 design §6 — S5–S7, D38's recorded change)

    /// The bracket speed keys with a feed open (E3-S2 design §6 — S5; the
    /// recorded contract change: `[`/`]` 33/30 previously fell to the
    /// default pass-through row — D38; the table's discipline means the
    /// change is recorded and pinned): plain `[` steps down, plain `]`
    /// steps up.
    @Test func plainBracketKeysStepSpeedWhenFeedIsOpen() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedDown
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedUp
        )
    }

    /// Speed-key auto-repeat = repeated steps (S6 — paging's and seek's
    /// repeat parity, `arrowAutoRepeatStillPages`/
    /// `seekAutoRepeatStillSteps`' sibling): a held `[`/`]` steps once
    /// per keyDown.
    @Test func speedKeyAutoRepeatStillSteps() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .speedDown
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true
            ) == .speedUp
        )
    }

    /// ⇧ alone is not a command modifier for the speed keys either —
    /// ⇧[` steps down like `[ (the frozen table's ⇧ policy; on a US
    /// layout these would type braces, but v1 has no text input).
    @Test func shiftAloneStillStepsSpeed() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedDown
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedUp
        )
    }

    /// Real bracket keyDown events carry system flags — those are not
    /// command modifiers and must still step (the arrow-flags regression
    /// pin's speed counterpart).
    @Test func systemSpeedFlagsStillStep() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedDown
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true
            ) == .speedUp
        )
    }

    /// ⌘/⌥/⌃-modified speed keys pass through — system shortcuts are
    /// never robbed (design §6's speed rows, the paging modifier columns).
    @Test func commandModifiedSpeedKeysPassThrough() {
        let commandModifiers: [NSEvent.ModifierFlags] = [
            [.command],
            [.option],
            [.control],
            [.command, .option, .control],
        ]
        for modifiers in commandModifiers {
            #expect(
                FeedKeyCommand.route(
                    keyCode: 33,
                    modifiers: modifiers,
                    isRepeat: false,
                    hasOpenFeed: true
                ) == .passThrough
            )
            #expect(
                FeedKeyCommand.route(
                    keyCode: 30,
                    modifiers: modifiers,
                    isRepeat: false,
                    hasOpenFeed: true
                ) == .passThrough
            )
        }
    }

    /// Welcome: the speed keys pass through like every key — no feed, no
    /// feed commands (D28 unchanged; the no-open-feed column).
    @Test func welcomePassesSpeedKeysThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    // MARK: ⌘L view toggle (E5-S1 design §5.1 — S3, S5, S16)

    /// ⌘L (key code 37 with .command) toggles in both presented views (S3,
    /// S5) — the row is claimed in the folder-open state regardless of
    /// which of the two views is presented. The recorded contract change:
    /// ⌘-modified keys previously passed through; ⌘L is now claimed while
    /// every other ⌘/⌥/⌃ combo still passes through.
    @Test func commandLTogglesInBothPresentedViews() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .toggleView
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .toggleView
        )
    }

    /// Welcome passes ⌘L through like every key (S16 — nothing to toggle
    /// without an open folder).
    @Test func welcomePassesCommandLThrough() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command],
                isRepeat: false,
                hasOpenFeed: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command],
                isRepeat: true,
                hasOpenFeed: false
            ) == .passThrough
        )
    }

    /// ⇧ alone does not modify the ⌘L row (the table's house convention):
    /// ⇧⌘L toggles like ⌘L, in both presented views.
    @Test func shiftCommandLStillToggles() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command, .shift],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .toggleView
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 37,
                modifiers: [.command, .shift],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .toggleView
        )
    }

    /// Every ⌘/⌥/⌃ combo other than ⌘L still passes through (the contract
    /// change's boundary — system shortcuts are otherwise never robbed),
    /// in both presented views: ⌥L, ⌃L, ⌘⌥⌃L, and a different ⌘-modified
    /// letter (⌘A, key code 0).
    @Test func otherCommandModifierCombosStillPassThrough() {
        let passThroughCases: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)] = [
            (37, [.option]),
            (37, [.control]),
            (37, [.command, .option, .control]),
            (0, [.command]),
        ]
        for testCase in passThroughCases {
            #expect(
                FeedKeyCommand.route(
                    keyCode: testCase.keyCode,
                    modifiers: testCase.modifiers,
                    isRepeat: false,
                    hasOpenFeed: true,
                    isListPresented: false
                ) == .passThrough
            )
            #expect(
                FeedKeyCommand.route(
                    keyCode: testCase.keyCode,
                    modifiers: testCase.modifiers,
                    isRepeat: false,
                    hasOpenFeed: true,
                    isListPresented: true
                ) == .passThrough
            )
        }
    }

    // MARK: List-presented rows (E5-S1 design §5.1 — S9, S13)

    /// List-presented plain ↑/↓ move the selection one row (S9). In the
    /// list ⇧ IS the extend modifier — the feed rows' "⇧ alone does not
    /// modify" reading inverts here, as the spec's S9 mandates.
    @Test func listPresentedPlainArrowsMoveSelection() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .moveSelection(.down)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .moveSelection(.up)
        )
    }

    /// List-presented ⇧-↑/⇧-↓ extend the selection from the anchor (S9) —
    /// the recorded inversion of `shiftAloneStillPages`.
    @Test func listPresentedShiftArrowsExtendSelection() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .extendSelection(.down)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.shift],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .extendSelection(.up)
        )
    }

    /// Real arrow keyDown events carry `.function`/`.numericPad` — not
    /// command modifiers; the list rows must route through them (the
    /// system-flags regression pin's list counterparts).
    @Test func systemArrowFlagsStillRouteListRows() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .moveSelection(.down)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .moveSelection(.up)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [.shift, .function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .extendSelection(.down)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.shift, .function, .numericPad],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .extendSelection(.up)
        )
    }

    /// Enter (36; keypad 76) activates the lead row (S13) — only while
    /// the list is presented (they are not feed keys; see the mirror pin
    /// below).
    @Test func listPresentedEnterActivatesTheLeadRow() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 36,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .activateLeadRow
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 76,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .activateLeadRow
        )
    }

    /// List-presented ←/→ are consumed quiet no-ops (a single-column list
    /// has no horizontal neighbor — D28's never-beep rule: consumed so
    /// they never reach the system's unhandled-key beep path).
    @Test func listPresentedLeftRightAreConsumedNoOps() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .ignore
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .ignore
        )
    }

    /// Auto-repeat = repeated calls on every list row (D38 parity): the
    /// machine's boundary clamp keeps repeats idempotent, so repeats
    /// route like first presses.
    @Test func listRowsAutoRepeatRepeatsCalls() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 125,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true,
                isListPresented: true
            ) == .moveSelection(.down)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 126,
                modifiers: [.shift],
                isRepeat: true,
                hasOpenFeed: true,
                isListPresented: true
            ) == .extendSelection(.up)
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 36,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true,
                isListPresented: true
            ) == .activateLeadRow
        )
    }

    /// The feed rows do not route while the list is presented (S5's
    /// never-compete rule): space and the bracket speed keys pass
    /// through, and the plain arrows route to the list machine instead
    /// of paging.
    @Test func feedRowsDoNotRouteWhileListIsPresented() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 49,
                modifiers: [],
                isRepeat: true,
                hasOpenFeed: true,
                isListPresented: true
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 33,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 30,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .passThrough
        )
    }

    /// The list rows do not route while the feed is presented (S5's
    /// never-compete rule, the mirror): Enter/keypad-Enter pass through,
    /// and ⇧-arrows keep their feed paging meaning (pinned by
    /// `shiftAloneStillPages`).
    @Test func listRowsDoNotRouteWhileFeedIsPresented() {
        #expect(
            FeedKeyCommand.route(
                keyCode: 36,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .passThrough
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 76,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .passThrough
        )
    }

    /// The list-presented and feed-presented row sets never overlap
    /// (§9.3): every shared key code routes to a different command per
    /// presented view — explicitly, the list's ←/→ are consumed no-ops
    /// while the feed's seek rows stay green (behavior-frozen).
    @Test func listAndFeedRowSetsNeverOverlap() {
        for keyCode: UInt16 in [123, 124, 125, 126] {
            let listCommand = FeedKeyCommand.route(
                keyCode: keyCode,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            )
            let feedCommand = FeedKeyCommand.route(
                keyCode: keyCode,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            )
            #expect(listCommand != feedCommand)
        }
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .ignore
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 123,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .seekBackward
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: true
            ) == .ignore
        )
        #expect(
            FeedKeyCommand.route(
                keyCode: 124,
                modifiers: [],
                isRepeat: false,
                hasOpenFeed: true,
                isListPresented: false
            ) == .seekForward
        )
    }
}
