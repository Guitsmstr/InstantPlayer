//
//  StubMediaPreviewService.swift
//  InstantPlayer
//
//  Feed Data stub for the preview seam (E2-S2, design §1 — house pattern).
//

import Foundation

/// Skeleton conformance for the preview seam. `preview(for:)` answers with
/// a canned constant for wiring tests; the real extraction pipeline
/// (`AVMediaPreviewService`, E2-S2 design §4) ships alongside it in Feed
/// Data.
///
/// Zero I/O: no FileManager, no AVFoundation, no ImageIO, nothing read from
/// disk — every value below is a fixed constant (design §1 table: stub
/// conformance for wiring tests).
nonisolated struct StubMediaPreviewService: MediaPreviewService {
    func wiringProbe() async -> String {
        "StubMediaPreviewService"
    }

    /// Canned answer (design §3 contract): a fixed constant preview for
    /// every item — the entry item is accepted and ignored. Idempotent by
    /// construction (the same constant every call).
    func preview(for _: MediaItem) async -> MediaPreview? {
        Self.cannedPreview
    }

    /// No cache and no in-flight work exists — the discard is a no-op,
    /// kept to honor the seam contract.
    func discardPreviews() async {}

    /// Fixed 1×1 preview carrying the canonical 1×1 PNG bytes — real
    /// display-ready image data (a platform-image wrap never fails on it),
    /// still a pure constant.
    private static let cannedPreview = MediaPreview(
        imageData: Data(Self.cannedPNG),
        pixelWidth: 1,
        pixelHeight: 1
    )

    /// Canonical 1×1 PNG.
    private static let cannedPNG: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
    ]
}
