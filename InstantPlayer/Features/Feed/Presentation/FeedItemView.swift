//
//  FeedItemView.swift
//  InstantPlayer
//
//  Feed Presentation — one feed page cell (E2-S2, design §2, §7 —
//  S2, S3, S12–S14; E2-S3, design §4, §6 — S6–S8: the player surface,
//  the whole-page tap target).
//

import AppKit
import SwiftUI

/// One feed page (E2-S2 design §2, §7; E2-S3 design §4, §6): a pure
/// function of one display state — the aspect-fit poster (S2, S3), the
/// current video's live playback surface (E2-S3 S8: the paused
/// presentation is the layer's frozen frame — no controls, no progress
/// indicator, no play button), the neutral unavailable state (S12, S13),
/// or the neutral loading presentation. The cell receives only the
/// display state and the drilled `onTap` closure — never the `MediaItem`
/// — so the file name is structurally absent from the viewport (S14;
/// D20: names display-only). Chrome-free (S14; E2-S3 S8): the cell
/// contains only the item or the placeholder. Geometry (S2): the
/// preview's intrinsic pixel size is the sole aspect input; the letterbox
/// is the window background (nothing painted) — the player layer
/// aspect-fits the same viewport-sized cell (E2-S3 design §4: resize and
/// native fullscreen need no code — none is added).
struct FeedItemView: View {
    /// The item's display state. `nil` (not yet requested) presents like
    /// `.loading` — the state machine sets `.loading` the moment it
    /// requests, so `nil` is at worst the same neutral presentation.
    let displayState: FeedItemDisplayState?

    /// The tap action (E2-S3 design §6 — S6, S7): drilled in per page by
    /// `FeedView`, which captures the item id and routes to the view
    /// model's guarded `togglePlaybackFromTap(itemID:)`. The cell never
    /// sees the item; the whole page — letterbox included — is the hit
    /// target (`.contentShape` below), and the guard matrix lives in the
    /// view model, not here.
    var onTap: () -> Void = {}

    /// The wrap memo (design §8(2), §1.1): the `Data` → platform-image
    /// wrap happens once per preview value, never per frame, never in
    /// `body` — `body` renders the pre-wrapped image only.
    @State private var wrappedFor: MediaPreview?
    @State private var poster: NSImage?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onAppear(perform: wrapPoster)
            .onChange(of: displayState) {
                wrapPoster()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch displayState ?? .loading {
        case let .preview(preview):
            if let poster {
                Image(nsImage: poster)
                    .resizable()
                    .aspectRatio(
                        CGFloat(preview.pixelWidth) / CGFloat(max(preview.pixelHeight, 1)),
                        contentMode: .fit
                    )
            } else {
                // One frame at most: the wrap lands in `onAppear` before
                // the cell is displayed.
                ProgressView()
            }
        case .unavailable:
            // The neutral unavailable state (design §7): one system symbol
            // and one neutral English word — no file name, no error codes,
            // no implied retry affordance (S12–S14).
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Unavailable")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        case let .player(playback):
            // The live playback surface (E2-S3 design §4): the session's
            // layer-hosting view, vended by the handle and wrapped by
            // `PlayerSurfaceView` (a wrap, not processing — D27). Paused
            // = the frozen frame only; no chrome of any kind ships here
            // (S8 — no controls, no progress indicator, no play button).
            PlayerSurfaceView(playback: playback)
        case .loading:
            // Neutral loading presentation (design §8(1): unknown-media
            // slowness degrades to `.loading`, never to a stall).
            ProgressView()
        }
    }

    /// The display-only wrap (design §1.1, §8(2) — a wrap, not
    /// processing): platform-image creation from the already-downsampled
    /// display bytes, memoized per preview value so repeated body runs
    /// never re-wrap.
    private func wrapPoster() {
        guard case let .preview(preview)? = displayState, wrappedFor != preview else { return }
        wrappedFor = preview
        poster = NSImage(data: preview.imageData)
    }
}
