//
//  MediaListRowView.swift
//  InstantPlayer
//
//  MediaList Presentation row (E5-S1, design §2, §3.3 — S1, S6–S8, S12,
//  S17).
//

import AppKit
import SwiftUI

/// One row (design §2): the file name (product R27) plus selection
/// styling and the S17 position highlight — nothing else (no thumbnails,
/// no metadata columns, no per-row controls; non-goals). The body is the
/// §7(2) budget: two O(1) membership checks (selection `Set` + highlight
/// equality) and one `Text` — ≤ 1 ms. Identity is `MediaItem.ID`; the row
/// is immutable per snapshot (S2) and renders only the snapshot's `name`
/// value (no file access, S14).
///
/// Gestures forward into the machine (S6–S8, S12): a single click sets
/// (never activates), ⌘-click toggles membership, ⇧-click extends from
/// the anchor, double-click emits the activation intent.
struct MediaListRowView: View {
    let item: MediaItem
    let viewModel: MediaListViewModel

    var body: some View {
        // The two O(1) checks of §7(2): selection membership and the S17
        // highlight projection.
        let isSelected = viewModel.selection.selectedIDs.contains(item.id)
        let isHighlighted = viewModel.highlightItemID == item.id

        Text(item.name)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(rowBackground(isSelected: isSelected, isHighlighted: isHighlighted))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                // S12 — activation is a navigation intent, not a selection
                // action. Attached first so the double-click recognizer
                // takes precedence over the single-click one.
                viewModel.activate(itemID: item.id)
            }
            .onTapGesture {
                // S6–S8 — the click's modifier flags pick the machine op
                // (the Finder conventions the spec adopts wholesale).
                // `NSEvent.modifierFlags` reflects the flags of the event
                // being dispatched — main-thread read inside the gesture
                // handler, no I/O.
                let modifiers = NSEvent.modifierFlags
                if modifiers.contains(.command) {
                    viewModel.toggleRow(item.id)
                } else if modifiers.contains(.shift) {
                    viewModel.extendToRow(item.id)
                } else {
                    viewModel.selectRow(item.id)
                }
            }
    }

    /// Selection and highlight styling — deliberately distinct (S17: the
    /// highlight is a position marker, never a selection).
    @ViewBuilder
    private func rowBackground(isSelected: Bool, isHighlighted: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.85))
        } else if isHighlighted {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
        }
    }
}
