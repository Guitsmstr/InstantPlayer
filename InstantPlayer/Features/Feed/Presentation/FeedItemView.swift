//
//  FeedItemView.swift
//  InstantPlayer
//
//  Feed Presentation — one feed page cell (E2-S2, design §2, §7 —
//  S2, S3, S12–S14; E2-S3, design §4, §6 — S6–S8: the player surface,
//  the whole-page tap target; E3-S1, design §4, §7 — S3, S11: the bar
//  overlay split; E3-S2, design §4, §7 — S1, S3: the speed drill).
//

import AppKit
import SwiftUI

/// The per-page overlay actions (E3-S1 design §7): scrub begin/change/
/// end, the track click, mouse-moved, and — since E3-S2 — the speed-menu
/// selection — each closure is captured with the page's item id at the
/// drill site (`FeedView`, the `onTap` precedent of E2-S3 §6) and routes
/// into the view model's guarded entry points (design §5 — the guard
/// matrix decides there, never here). The cell never sees the item.
struct FeedPageActions {
    let scrubBegan: () -> Void
    let scrubChanged: (Double) -> Void
    let scrubEnded: (Double) -> Void
    let trackClick: (Double) -> Void
    let mouseMoved: () -> Void

    /// The speed-menu selection (E3-S2 design §6): routes to the view
    /// model's guarded `selectSpeed(_:itemID:)` — the item id is captured
    /// at the drill site.
    let speedSelected: (MediaPlaybackSpeed) -> Void
}

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

    /// The page's item id (E3-S1 design §4): the mouse-move tracking area
    /// reports it. The id is not the item (S14's structural absence
    /// holds; names stay display-only, D20). Unwired (`nil`) until the
    /// feed drills it — unwired movement reports nothing.
    var itemID: MediaItem.ID? = nil

    /// The tap action (E2-S3 design §6 — S6, S7): drilled in per page by
    /// `FeedView`, which captures the item id and routes to the view
    /// model's guarded `togglePlaybackFromTap(itemID:)`. The cell never
    /// sees the item; the whole page — letterbox included — is the hit
    /// target (`.contentShape` below), and the guard matrix lives in the
    /// view model, not here.
    var onTap: () -> Void = {}

    /// The bar overlay's per-page model (E3-S1 design §7): `nil` is the
    /// structural absence (image pages, unavailable items, non-current
    /// pages, mid-paging — S4, S12); a non-`nil` model with
    /// `isVisible == false` renders the strip fully inert.
    var controlBarModel: PlaybackControlBarModel? = nil

    /// The per-page overlay actions (E3-S1 design §7) — unwired (`nil`)
    /// shows no strip and reports no movement.
    var actions: FeedPageActions? = nil

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
            // E5-S1 (design §5.2 — §12(7)'s sanctioned Feed edit): a
            // poster page — an image page or a video at rest — reports
            // mouse movement through the same tracking mechanism as the
            // live surface (`PlayerSurfaceView`), so the demand signal
            // reaches both page kinds. The wrap is transparent and
            // full-bleed (letterbox included), adds no chrome (S14),
            // and renders the memoized poster exactly as before.
            PosterMouseMoveTracker(onMouseMoved: { actions?.mouseMoved() })
                .overlay {
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
            // = the frozen frame only (S8). Per-session view identity
            // (design §4 implementation correction): the representable is
            // rebuilt when the session changes — `.id` keyed to the
            // handle's identity; one rebuild per session, never per frame
            // (design §8(5), RNF-02).
            //
            // E3-S1 (design §4, §7 — S11's carve-out): the page is a
            // ZStack of two sibling layers — the tap surface (full-bleed;
            // its own contentShape + tap below) and, above it, the bar
            // strip rendered iff the page's bar model exists (structural
            // absence on image pages, unavailable items, non-current
            // pages, and mid-paging — S4, S12). The strip's own
            // contentShape and gestures hit-test above the tap surface,
            // so the whole strip is excluded from the whole-page toggle
            // target; hidden at rest the strip is fully inert
            // (`opacity(0)` + `allowsHitTesting(false)`) — a hidden bar
            // can never swallow clicks, and the whole-page toggle stays
            // intact (the E2-S3 S8 amendment: chrome is demand-driven).
            ZStack(alignment: .bottom) {
                PlayerSurfaceView(
                    playback: playback,
                    itemID: itemID,
                    onMouseMoved: { _ in actions?.mouseMoved() }
                )
                .id(ObjectIdentifier(playback))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                if let model = controlBarModel, let actions {
                    PlaybackControlBarView(
                        model: model,
                        onScrubBegan: actions.scrubBegan,
                        onScrubChanged: actions.scrubChanged,
                        onScrubEnded: actions.scrubEnded,
                        onTrackClick: actions.trackClick,
                        onSpeedSelected: actions.speedSelected
                    )
                    .opacity(model.isVisible ? 1 : 0)
                    .allowsHitTesting(model.isVisible)
                }
            }
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

/// The poster-page mouse-move tracker (E5-S1 design §5.2 — §12(7)'s
/// sanctioned Feed edit): a transparent, full-bleed `NSTrackingArea`
/// wrap reporting pointer movement over a poster page, so the demand
/// signal covers image pages and videos at rest exactly as
/// `PlayerSurfaceView` covers the live surface — same area options,
/// same explicit `@objc(mouseMoved:)` selector (see
/// `PlayerSurfaceView.Coordinator`'s pitfall note), same window flag.
/// AppKit-only plumbing, no chrome, no state: the sink is the page's
/// drilled `FeedPageActions.mouseMoved` closure, so the id capture
/// stays at the drill site.
private struct PosterMouseMoveTracker: NSViewRepresentable {
    /// The mouse-moved sink — `FeedPageActions.mouseMoved`; unwired
    /// movement (a `nil` actions value) reports nothing.
    var onMouseMoved: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: context.coordinator,
                userInfo: nil
            )
        )
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        // The coordinator-held sink is the only mutable part — refreshed
        // every update so `mouseMoved` always reaches the current page's
        // actions.
        context.coordinator.onMouseMoved = onMouseMoved
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMouseMoved: onMouseMoved)
    }

    /// The tracking view: besides hosting the area it re-asserts
    /// `NSWindow.acceptsMouseMovedEvents` the moment it joins a window —
    /// AppKit gates `mouseMoved` delivery on that flag, and on a
    /// poster-only feed no `PlayerSurfaceView` ever sets it.
    private final class TrackingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
        }
    }

    /// The tracking area's owner (`PlayerSurfaceView.Coordinator`'s
    /// pattern): the explicit `@objc(mouseMoved:)` lands the method on
    /// the selector AppKit actually dispatches; AppKit delivers on the
    /// main thread.
    @MainActor
    final class Coordinator: NSObject {
        var onMouseMoved: () -> Void

        init(onMouseMoved: @escaping () -> Void) {
            self.onMouseMoved = onMouseMoved
        }

        @objc(mouseMoved:) func mouseMoved(with _: NSEvent) {
            onMouseMoved()
        }
    }
}
