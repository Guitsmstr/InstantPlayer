//
//  MediaPlayerService.swift
//  InstantPlayer
//
//  Feed Domain player seam (E1-S3, design §3.5 — R2, R10, R11).
//

/// Player service seam (R11): Presentation and Domain reach playback only
/// through this abstraction — never AVKit/AVPlayer directly. Owned by
/// Feed's Domain because playback has one v1 consumer (seam placement
/// rule, design §2.2). Domain stays Swift-pure (R10): no imports at all.
protocol MediaPlayerService: Sendable {
    /// Wiring probe — same contract as MediaFolderRepository.wiringProbe().
    func wiringProbe() async -> String
}
