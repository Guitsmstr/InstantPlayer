//
//  FeedItemView.swift
//  InstantPlayer
//
//  Feed Presentation — one feed page cell (E2-S2, design §2, §7 —
//  S2, S3, S12–S14).
//

import AppKit
import SwiftUI

/// One feed page (design §2, §7): a pure function of one display state —
/// the aspect-fit poster (S2, S3), the neutral unavailable state (S12,
/// S13), or the neutral loading presentation. The cell receives only the
/// display state — never the `MediaItem` — so the file name is
/// structurally absent from the viewport (S14; D20: names display-only).
/// Chrome-free (S14): the cell contains only the item or the placeholder.
/// Geometry (S2): the preview's intrinsic pixel size is the sole aspect
/// input; the letterbox is the window background (nothing painted).
/// Video and image make no layout difference in this story (design §2) —
/// both render as the static preview; the poster is the whole visible
/// video contract until E2-S3 (S3 — no motion, no transport).
struct FeedItemView: View {
    /// The item's display state. `nil` (not yet requested) presents like
    /// `.loading` — the state machine sets `.loading` the moment it
    /// requests, so `nil` is at worst the same neutral presentation.
    let displayState: FeedItemDisplayState?

    /// The wrap memo (design §8(2), §1.1): the `Data` → platform-image
    /// wrap happens once per preview value, never per frame, never in
    /// `body` — `body` renders the pre-wrapped image only.
    @State private var wrappedFor: MediaPreview?
    @State private var poster: NSImage?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .player:
            // The live playback surface (E2-S3 design §4) — the session's
            // layer owns this space. Interim presentation only: the real
            // display-ready-view wrap (`PlayerSurfaceView`) lands with the
            // view task (E2-S3 task 5), and this state is unreachable
            // while the composition still binds the stub seam (stub
            // handles emit no events).
            Color.black
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
