//
//  FeedKeyCommand.swift
//  InstantPlayer
//
//  App-owned feed-key routing decision (E2-S2 round 4 — evidence §8 —
//  S5; coordinator-ratified amendment to design §5.3's delivery
//  mechanism, D22; extended into a feed-key router in E2-S3 — design §6;
//  E3-S1, design §6 — S2, S9: the keyboard seek rows; E3-S2, design §6 —
//  S5–S7: the keyboard speed rows).
//

import AppKit

/// The feed-key delivery decision (E2-S2 round 4 — evidence §8): a pure,
/// unit-testable routing table over `NSEvent`-derived inputs. SwiftUI
/// focused-view delivery — `.onKeyPress` / `.onMoveCommand` with
/// programmatic `@FocusState` — failed three live functional-review
/// rounds on macOS 26: key focus could not be made to land in the scroll
/// content, so arrow keys fell through unhandled. The ratified amendment
/// routes key events through an App-owned `NSEvent` local monitor (D10)
/// into the unchanged view-model paging methods; this type is the
/// decision itself, taking values rather than an `NSEvent` so the table
/// is testable without event fixtures. E2-S3 (design §6) grows the table
/// into a feed-key router — space toggles playback, auto-repeat is
/// consumed and ignored; the arrow rows are behavior-frozen.
enum FeedKeyCommand: Equatable {
    /// Page to the next item (S5).
    case pageForward

    /// Page to the previous item (S5).
    case pageBackward

    /// Toggle play/pause (E2-S3 S5) — the view model's guard matrix
    /// decides what a toggle does (image pages and mid-gesture presses
    /// consume and no-op quietly, design §6).
    case togglePlayback

    /// Seek −5 s (E3-S1 S2, design §6) — always consumed with an open
    /// feed; the view model's guard matrix decides (ineligible states
    /// consume and no-op quietly, never beep — D28). Auto-repeat =
    /// repeated steps (S9).
    case seekBackward

    /// Seek +5 s (E3-S1 S2, design §6) — `seekBackward`'s mirror.
    case seekForward

    /// Step one preset down the speed ladder (E3-S2 S5, design §6) —
    /// always consumed with an open feed; the view model's guard matrix
    /// decides (ineligible states consume and no-op quietly, never beep —
    /// S16, D28). Auto-repeat = repeated steps (S6, the D22/D34 parity);
    /// ladder-end repeats clamp idempotently (S7).
    case speedDown

    /// Step one preset up — `speedDown`'s mirror.
    case speedUp

    /// Consume the event and do nothing (E2-S3 design §6 — space
    /// auto-repeat: a held space must not flap play/pause).
    case ignore

    /// The event is not ours — deliver it to the app untouched.
    case passThrough

    /// The routing decision (main-thread O(1) — the monitor's only work):
    ///
    /// - With no feed open (welcome), everything passes through.
    /// - The plain (unmodified) ↓/↑ keys page, identified by hardware key
    ///   code (`NSEvent.keyCode`): 125 = down arrow, 126 = up arrow (the
    ///   codes behind AppKit's function-key constants). Raw key codes are
    ///   deliberate and pinned by the unit tests.
    /// - Space (keyCode 49) toggles playback on the first press; an
    ///   auto-repeat (`isRepeat`) is consumed and ignored — a held space
    ///   must never flap play/pause (E2-S3 design §6).
    /// - ⌘/⌥/⌃ combinations pass through: system shortcuts are never
    ///   robbed, and future text input keeps its command keys. ⇧ alone is
    ///   not a command modifier — ⇧↓/⇧↑ page and ⇧space toggles, like
    ///   the unmodified keys (v1 has no text input; revisit with E3
    ///   chrome if one appears).
    /// - Any other key passes through.
    /// - E3-S1 (design §6 — S2, S9): the plain ←/→ keys (123/124) are the
    ///   keyboard seek rows — with a feed open they are **always
    ///   consumed** and routed to the guard matrix (which no-ops quietly
    ///   on ineligible states; passing through would re-expose them to
    ///   the system's unhandled-key path, the D28 beep lesson); auto-
    ///   repeat = repeated steps (S9, paging's parity); ⇧ alone does not
    ///   modify. A deliberate contract change: 123/124 previously passed
    ///   through (the recorded consequence, design §10.1).
    /// - E3-S2 (design §6 — S5–S7): the plain `[`/`]` keys (33/30) are
    ///   the keyboard speed rows — with a feed open they are **always
    ///   consumed** and routed to the guard matrix (the seek rows'
    ///   shape, D28's beep lesson); auto-repeat = repeated steps (S6,
    ///   the D22/D34 parity); ⇧ alone does not modify (⇧[` steps down
    ///   like `[`). A deliberate contract change: 33/30 previously fell
    ///   to the default pass-through row (the recorded consequence,
    ///   D38, pinned by new tests).
    static func route(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool,
        hasOpenFeed: Bool
    ) -> FeedKeyCommand {
        guard hasOpenFeed else { return .passThrough }
        let commandModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        guard modifiers.isDisjoint(with: commandModifiers) else { return .passThrough }
        switch keyCode {
        case Self.spaceKeyCode:
            return isRepeat ? .ignore : .togglePlayback
        case Self.downArrowKeyCode:
            return .pageForward
        case Self.upArrowKeyCode:
            return .pageBackward
        case Self.leftArrowKeyCode:
            return .seekBackward
        case Self.rightArrowKeyCode:
            return .seekForward
        case Self.leftBracketKeyCode:
            return .speedDown
        case Self.rightBracketKeyCode:
            return .speedUp
        default:
            return .passThrough
        }
    }

    /// Hardware key codes (`NSEvent.keyCode`): space = 49, down = 125,
    /// up = 126, left = 123, right = 124 — the seek rows landed with
    /// E3-S1 (design §6); raw key codes stay deliberate and test-pinned.
    /// E3-S2 (design §6, §0 fact 3 — verified against HIToolbox
    /// `Events.h` in the pinned SDK): `[` = `kVK_ANSI_LeftBracket` =
    /// 0x21 = 33, `]` = `kVK_ANSI_RightBracket` = 0x1E = 30.
    private static let spaceKeyCode: UInt16 = 49
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let leftBracketKeyCode: UInt16 = 33
    private static let rightBracketKeyCode: UInt16 = 30
}
