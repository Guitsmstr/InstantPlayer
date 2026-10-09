//
//  StubMediaPlayerService.swift
//  InstantPlayer
//
//  Feed Data stub for the player seam (E1-S3, design §3.6 — R2).
//

/// Skeleton conformance for the player seam. The AVKit-backed wrapper
/// (D1) arrives with the Feed playback story; this stub keeps the
/// skeleton framework-free.
struct StubMediaPlayerService: MediaPlayerService {
    func wiringProbe() async -> String {
        "StubMediaPlayerService"
    }
}
