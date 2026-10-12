//
//  PlayerSurfaceView.swift
//  InstantPlayer
//
//  Feed Presentation — the display-ready-view wrap (E2-S3, design §1.1,
//  §4 — S8; D27).
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
/// session and `updateNSView` is a no-op — the handle is immutable per
/// session, so `body` renders a pre-wrapped surface, never a per-frame
/// rebuild (design §8(5), RNF-02).
struct PlayerSurfaceView: NSViewRepresentable {
    /// The live playback-session handle — its display view is vended
    /// exactly once, in `makeNSView`.
    let playback: any MediaPlayback

    func makeNSView(context _: Context) -> NSView {
        // The seam's contract (E2-S3 design §2, §4): a display-ready
        // platform view — the Data conformance's layer-hosting `NSView`
        // (`AVPlayerLayer`, `.resizeAspect`). The conditional cast is the
        // honest bridge over the opaque `AnyObject`; the fallback empty
        // view keeps the wrap total without ever processing media.
        playback.makeDisplayView() as? NSView ?? NSView()
    }

    func updateNSView(_: NSView, context _: Context) {
        // No-op by contract (E2-S3 design §4): the handle is immutable
        // per session — nothing to update, ever.
    }
}
