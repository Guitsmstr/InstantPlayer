//
//  MediaFolderRepository.swift
//  InstantPlayer
//
//  Core filesystem seam (E1-S3, design §3.4 — R7, R11, R12; E2-S1, design §2).
//

/// The ONLY sanctioned path to the filesystem for both v1 features (R11).
/// Shaped so security-scoped resource handling (RNF-04: bookmarks,
/// start/stop access, sandbox-safe resolution) stays BEHIND this seam
/// without changing its callers (R12).
///
/// Nonisolated on purpose: this is a pure contract — isolation belongs to
/// conformances (R12). The shipped conformance is an actor whose entry-time
/// work must run off the main thread (E2-S1 design §7.2); the project's
/// default-MainActor isolation must not pin the seam to main.
nonisolated protocol MediaFolderRepository: Sendable {
    /// Wiring probe: constant from the bound conformance; proves the
    /// binding in tests (R16). Unchanged since E1-S3.
    func wiringProbe() async -> String

    /// Entry/collection operation (E2-S1, design §2 — S1–S4, S8–S14).
    ///
    /// Contract: derives the one folder to open from `entryAction` per
    /// S1–S4 (media file → its parent; folder → itself; unsupported file →
    /// its parent, the file never collected), collects that folder's
    /// direct-children media per S10–S12/S14, and resolves the starting
    /// item per design §3.3 step 6 — the entered file's index when that
    /// file is part of the collection, otherwise the first item. The
    /// security-scoped session (S8–S9) is managed entirely behind the seam:
    /// conformances start and stop scoped access internally, and there are
    /// deliberately no start/stop members — callers cannot misuse the
    /// session, and E2-S2/E2-S3 consume the seam unchanged.
    ///
    /// Returns `nil` when no folder opens: an unreadable/missing folder, or
    /// a derived folder with no media — the caller then presents the welcome
    /// state (S5–S7). Never throws: every failure mode is fail-open
    /// (design §5.3) and empty results are product states, not errors.
    /// Exactly one folder scan per call; the returned value is the caller's
    /// snapshot (S13).
    func prepareCollection(forEntryAt entryAction: EntryAction) async -> MediaCollection?
}
