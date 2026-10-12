//
//  FeedKeyCommand.swift
//  InstantPlayer
//
//  App-owned feed-key routing decision (E2-S2 round 4 — evidence §8 —
//  S5; coordinator-ratified amendment to design §5.3's delivery
//  mechanism, D22; extended into a feed-key router in E2-S3 — design §6).
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
    /// - Any other key (including ←/→, 123/124) passes through.
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
        default:
            return .passThrough
        }
    }

    /// Hardware key codes (`NSEvent.keyCode`): space = 49, down = 125,
    /// up = 126 (left = 123 / right = 124 are deliberately unrouted).
    private static let spaceKeyCode: UInt16 = 49
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
}
