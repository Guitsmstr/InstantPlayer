//
//  MediaItem.swift
//  InstantPlayer
//
//  Core collected-item value (E2-S1, design §5.4 — S11, S13).
//

import Foundation

/// The kind of a collected media item, decided at collection time by the
/// system-declared content type's conformance to the video/image families
/// (S11 — design §5.2). Never derived from the file name.
nonisolated enum MediaItemKind: Hashable, Sendable {
    case video
    case image
}

/// One collected media item (design §5.4): identity + resolved file URL +
/// display name + kind. A point-in-time snapshot value (S13): `name` is the
/// display name captured at open (last path component); the item never
/// re-reads the folder. File names are display-only — never logged
/// unredacted, never parsed (design §8.3).
nonisolated struct MediaItem: Hashable, Sendable, Identifiable {
    /// Identity within a snapshot: the item's resolved file URL.
    let id: URL
    /// The item's file URL (the same value as `id`; the seam contract names
    /// identity and location separately).
    let url: URL
    /// Display name — the last path component, captured at open.
    let name: String
    /// Video or image, per the UTType-conformance rule (S11).
    let kind: MediaItemKind
}
