//
//  FeedKeyCommand.swift
//  InstantPlayer
//
//  App-owned feed-key routing decision (E2-S2 round 4 — evidence §8 —
//  S5; coordinator-ratified amendment to design §5.3's delivery
//  mechanism, D22; extended into a feed-key router in E2-S3 — design §6;
//  E3-S1, design §6 — S2, S9: the keyboard seek rows; E3-S2, design §6 —
//  S5–S7: the keyboard speed rows; E5-S1, design §5.1 — S3, S9, S13:
//  the ⌘L view-toggle row and the list-presented rows).
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

    /// Toggle between the list view and the feed (E5-S1 design §5.1 —
    /// S3, S5): ⌘L (key code 37 = `kVK_ANSI_L`, with `.command`), claimed
    /// in the folder-open state in **both** presented views. A recorded
    /// contract change: ⌘-modified keys previously passed through
    /// ("system shortcuts are never robbed") — ⌘L is now claimed while
    /// every other ⌘/⌥/⌃ combo still passes through; the monitor
    /// dispatches it to the registered list model's one toggle (the same
    /// method the button calls).
    case toggleView

    /// Move the list selection one row (E5-S1 design §5.1 — S9): the
    /// plain ↑/↓ rows while the list is presented. Auto-repeat =
    /// repeated calls; the machine's boundary clamp keeps repeats
    /// idempotent (the D38 parity).
    case moveSelection(MediaListSelection.Direction)

    /// Extend the list selection from the anchor (E5-S1 design §5.1 —
    /// S9): the ⇧-↑/⇧-↓ rows while the list is presented — in the list ⇧
    /// IS the extend modifier (the spec's S9 mandate inverts the feed
    /// rows' "⇧ alone does not modify" reading).
    case extendSelection(MediaListSelection.Direction)

    /// Activate the list's lead row (E5-S1 design §5.1 — S13): the Enter
    /// rows (36; keypad 76) while the list is presented — the keyboard
    /// twin of double-click, dispatched into the view model's activation
    /// path (§4's no-restart rule for the already-current row lives in
    /// the model).
    case activateLeadRow

    /// Consume the event and do nothing (E2-S3 design §6 — space
    /// auto-repeat: a held space must not flap play/pause; E5-S1 — the
    /// list's ←/→ rows: a single-column list has no horizontal neighbor,
    /// consumed quiet no-ops so they never reach the system's
    /// unhandled-key beep path, D28).
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
    /// - E5-S1 (design §5.1 — S3, S9, S13, S16): the folder-open guard
    ///   (`hasOpenFeed`) generalizes to the presented-state input — the
    ///   sibling `isListPresented` flag selects the active row set (one
    ///   presented view, one active row set — S5's never-compete rule;
    ///   welcome still passes everything through, S16). The ⌘L row (37
    ///   with `.command`) is the view toggle in both presented views —
    ///   the recorded contract change above; ⇧ alone does not modify
    ///   it (⇧⌘L toggles like ⌘L). While the **list** is presented the
    ///   rows are the list's: plain ↑/↓ (126/125) move the selection,
    ///   ⇧-↑/⇧-↓ extend from the anchor (in the list ⇧ IS the extend
    ///   modifier — the feed rows' ⇧ reading inverts), Enter (36;
    ///   keypad 76) activates the lead row, and ←/→ (123/124) are
    ///   consumed quiet no-ops; auto-repeat = repeated calls (the
    ///   machine's clamp keeps boundary repeats idempotent). The feed
    ///   rows below route **only while the feed is presented** and stay
    ///   behavior-frozen.
    static func route(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool,
        hasOpenFeed: Bool,
        isListPresented: Bool = false
    ) -> FeedKeyCommand {
        guard hasOpenFeed else { return .passThrough }
        // The ⌘L row (E5-S1 design §5.1 — S3): claimed before the
        // command-modifier pass-through guard — the one deliberate
        // exception to "system shortcuts are never robbed". ⇧ alone does
        // not modify (the house convention); ⌥/⌃ still pass through.
        if keyCode == lKeyCode,
           modifiers.contains(.command),
           modifiers.isDisjoint(with: [.option, .control])
        {
            return .toggleView
        }
        let commandModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        guard modifiers.isDisjoint(with: commandModifiers) else { return .passThrough }
        // The list-presented rows (E5-S1 design §5.1 — S9, S13).
        if isListPresented {
            switch keyCode {
            case Self.downArrowKeyCode:
                return modifiers.contains(.shift) ? .extendSelection(.down) : .moveSelection(.down)
            case Self.upArrowKeyCode:
                return modifiers.contains(.shift) ? .extendSelection(.up) : .moveSelection(.up)
            case Self.returnKeyCode, Self.keypadEnterKeyCode:
                return .activateLeadRow
            case Self.leftArrowKeyCode, Self.rightArrowKeyCode:
                return .ignore
            default:
                return .passThrough
            }
        }
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
    /// 0x21 = 33, `]` = `kVK_ANSI_RightBracket` = 0x1E = 30. E5-S1
    /// (design §5.1, same verification): `L` = `kVK_ANSI_L` = 0x25 = 37,
    /// Return = `kVK_Return` = 0x24 = 36, keypad Enter =
    /// `kVK_ANSI_KeypadEnter` = 0x4C = 76.
    private static let spaceKeyCode: UInt16 = 49
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let leftBracketKeyCode: UInt16 = 33
    private static let rightBracketKeyCode: UInt16 = 30
    private static let lKeyCode: UInt16 = 37
    private static let returnKeyCode: UInt16 = 36
    private static let keypadEnterKeyCode: UInt16 = 76
}
