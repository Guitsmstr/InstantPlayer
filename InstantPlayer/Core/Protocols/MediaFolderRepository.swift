//
//  MediaFolderRepository.swift
//  InstantPlayer
//
//  Core filesystem seam (E1-S3, design §3.4 — R7, R11, R12).
//

/// The ONLY sanctioned path to the filesystem for both v1 features (R11).
/// Shaped so security-scoped resource handling (RNF-04: bookmarks,
/// start/stop access, sandbox-safe resolution) can be added BEHIND this
/// seam without changing its callers (R12). Real operations arrive with
/// the feature stories that need them.
protocol MediaFolderRepository: Sendable {
    /// Wiring probe: constant from the bound conformance; proves the
    /// binding in tests (R16). Replaced by real operations later.
    func wiringProbe() async -> String
}
