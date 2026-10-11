//
//  MediaTypeClassifier.swift
//  InstantPlayer
//
//  Feed Data helper — the S11 media rule + junk exclusions (E2-S1, design §5.2).
//

import Foundation
import UniformTypeIdentifiers

/// Data-internal classification of probed filesystem facts (design §5.2 —
/// S11, S12; untrusted-input rule §8.3).
///
/// Honest contract, recorded deliberately: the media judgment is the
/// system's DECLARED type (`URLResourceValues.contentType` — extension- and
/// metadata-based). Content bytes are never sniffed at collection time; a
/// mislabeled file collects as its declared kind and surfaces as
/// unplayable at consumption (E2-S3's failure handling). No hardcoded
/// extension list, no name parsing (S11); file names are display-only
/// (§8.3) and never read by this rule.
nonisolated enum MediaTypeClassifier {
    /// The S11 rule as one predicate plus kind. Include an entry iff all
    /// of (design §5.2):
    ///
    /// 1. it is a regular file — excludes directories, packages/bundles,
    ///    symlinks, fifos/sockets/devices; a symlink's target is never
    ///    followed and never pulls content into the collection (§8.3);
    /// 2. it is not hidden (`URLResourceValues.isHidden` — covers dot-names
    ///    and the hidden flag, keeping `.DS_Store` and AppleDouble `._*`
    ///    junk out);
    /// 3. its declared content type conforms to the system video family
    ///    (`UTType.movie` or `UTType.video` → `.video`) or image family
    ///    (`UTType.image` → `.image`).
    ///
    /// Returns the collected kind, or `nil` when the entry is excluded
    /// (S12 — the boundary the whole app inherits).
    static func mediaKind(of values: URLResourceValues) -> MediaItemKind? {
        // Rule 1 — regular files only (junk/links/special files excluded).
        guard values.isRegularFile == true else { return nil }
        // Rule 2 — not hidden (dot-names and the hidden flag).
        guard values.isHidden != true else { return nil }
        // Rule 3 — declared content type conformance (no name reading).
        guard let contentType = values.contentType else { return nil }
        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return .video
        }
        if contentType.conforms(to: .image) {
            return .image
        }
        return nil
    }
}
