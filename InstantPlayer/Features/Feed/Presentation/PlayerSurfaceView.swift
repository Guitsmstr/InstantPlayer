//
//  PlayerSurfaceView.swift
//  InstantPlayer
//
//  Feed Presentation — the display-ready-view wrap (E2-S3, design §1.1,
//  §4 — S8; D27) grown the mouse-move tracking area (E3-S1, design §4 —
//  S3).
//

import AppKit
import SwiftUI

/// The playback surface wrap (E2-S3 design §4): an `NSViewRepresentable`
/// that vends the session handle's display-ready platform view into the
/// hierarchy — a wrap, not processing (the architecture §4 check-3
/// refinement, D27). AppKit only — no AVFoundation/AVKit import lands in
/// Presentation: the layer-hosting view is built and configured in Feed
/// Data (`MediaPlayback.makeDisplayView()`), and this wrap performs no
/// media operation of any kind. `makeNSView` vends the view once per
/// session and `updateNSView` refreshes only the coordinator-held
/// mouse-move plumbing — the wrap itself stays once-per-session, so
/// `body` renders a pre-wrapped surface, never a per-frame rebuild
/// (design §8(5), RNF-02).
///
/// E3-S1 (design §4): the wrap installs an `NSTrackingArea` on the
/// surface it already vends — AppKit-only plumbing on the Presentation
/// side; the Data display view stays interaction-free (D27). The area
/// (`.mouseMoved`, `.activeInKeyWindow`, `.inVisibleRect`) covers the
/// whole surface (full-bleed; the letterbox is inside it) and stays
/// correct across resize and native fullscreen (`.inVisibleRect`); each
/// `mouseMoved` reaches the view model through the coordinator-held
/// closure as `noteMouseMoved(itemID:)` — the deterministic 1:1
/// mechanism, no focus dependence (E2-S2 evidence §8's lesson). The
/// design §4's recorded fallback is **taken** (review-ratified): the
/// surface enables `NSWindow.acceptsMouseMovedEvents` for its own window
/// — AppKit gates `mouseMoved` delivery on that flag, and without it the
/// tracking area could exist while the window never delivers.
/// (Recorded as a ratified deviation in the story's evidence.)
struct PlayerSurfaceView: NSViewRepresentable {
    /// The live playback-session handle — its display view is vended
    /// exactly once, in `makeNSView`.
    let playback: any MediaPlayback

    /// The item id this surface's page carries — every `mouseMoved`
    /// reports it. Unwired (`nil`) until the feed drills the real value
    /// (task 7's wiring); unwired movement reports nothing.
    var itemID: MediaItem.ID?

    /// The mouse-moved sink (design §4) — the coordinator-held closure.
    /// Unwired (a no-op) until task 7 drills the view model's
    /// `noteMouseMoved(itemID:)`.
    var onMouseMoved: (MediaItem.ID) -> Void = { _ in }

    func makeNSView(context: Context) -> NSView {
        // The seam's contract (E2-S3 design §2, §4): a display-ready
        // platform view — the Data conformance's layer-hosting `NSView`
        // (`AVPlayerLayer`, `.resizeAspect`). The conditional cast is the
        // honest bridge over the opaque `AnyObject`; the fallback empty
        // view keeps the wrap total without ever processing media.
        let view = playback.makeDisplayView() as? NSView ?? NSView()
        // The tracking area (design §4): installed once, on the vended
        // surface — `.inVisibleRect` recomputes the rect from the view's
        // visible rect on every tracking update, so resize and native
        // fullscreen need no geometry code here.
        view.addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: context.coordinator,
                userInfo: nil
            )
        )
        enableMouseMoved(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The coordinator-held plumbing is the only mutable part (design
        // §4): refreshed on every update so `mouseMoved` always reaches
        // the current page's id and sink — the vended view itself is
        // never touched (once per session, E2-S3 design §4).
        context.coordinator.itemID = itemID
        context.coordinator.onMouseMoved = onMouseMoved
        // The window flag may only be settable once the view is in the
        // hierarchy — every update re-asserts it (idempotent, scoped to
        // this surface's own window).
        enableMouseMoved(on: nsView)
    }

    /// The design §4 recorded fallback, taken (coordinator-ratified in
    /// review): AppKit gates `mouseMoved` delivery on
    /// `NSWindow.acceptsMouseMovedEvents`, which defaults off for windows
    /// that never opted in — without this one AppKit line the tracking
    /// area could exist while the window never delivers. Scoped to this
    /// surface's own window only; idempotent.
    private func enableMouseMoved(on view: NSView) {
        view.window?.acceptsMouseMovedEvents = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(itemID: itemID, onMouseMoved: onMouseMoved)
    }

    /// The tracking area's owner (design §4): forwards each `mouseMoved`
    /// to the sink with the page's item id. Main-actor confined — AppKit
    /// delivers on the main thread; the sink is the view model's
    /// `noteMouseMoved(itemID:)`.
    @MainActor
    final class Coordinator: NSObject {
        var itemID: MediaItem.ID?
        var onMouseMoved: (MediaItem.ID) -> Void

        init(itemID: MediaItem.ID?, onMouseMoved: @escaping (MediaItem.ID) -> Void) {
            self.itemID = itemID
            self.onMouseMoved = onMouseMoved
        }

        /// `@objc(mouseMoved:)` — the selector pinned **explicitly** and
        /// on purpose: `NSTrackingArea` messages its owner with
        /// `mouseMoved:` (the `NSResponder` selector), but plain selector
        /// synthesis on an `NSObject` subclass does not inherit that
        /// imported declaration — `@objc func mouseMoved(with:)`
        /// synthesizes `mouseMovedWith:`, which the tracking area never
        /// sends (the functional-review defect: the bar never showed).
        /// The explicit annotation lands the method on the selector
        /// AppKit actually dispatches. AppKit delivers on the main
        /// thread.
        @objc(mouseMoved:) func mouseMoved(with _: NSEvent) {
            guard let itemID else { return }
            onMouseMoved(itemID)
        }
    }
}
