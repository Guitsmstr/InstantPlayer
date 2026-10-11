//
//  MediaPreview.swift
//  InstantPlayer
//
//  Feed Domain preview value (E2-S2, design §3 — S2, S3).
//

import Foundation

/// The preview seam's output value (E2-S2 design §3): display-ready encoded
/// image bytes plus the intrinsic pixel size. Domain stays Foundation-only
/// (R10) — the seam cannot return `NSImage`/`CGImage`, so the value travels
/// like the `URL` precedent: operations (decode, extract, downsample,
/// encode) live only in Data conformances; Presentation wraps the display
/// bytes into a platform image for rendering — a wrap, not processing
/// (design §1.1). The bytes are already downsampled, so the wrap is cheap.
nonisolated struct MediaPreview: Equatable, Sendable {
    /// Display-ready encoded image bytes (ImageIO-produced JPEG at display
    /// size — design §3).
    let imageData: Data

    /// The preview's intrinsic pixel width — aspect-preserving; the sole
    /// input to aspect-fit letterboxing (S2).
    let pixelWidth: Int

    /// The preview's intrinsic pixel height (S2).
    let pixelHeight: Int
}
