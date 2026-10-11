//
//  StubMediaFolderRepository.swift
//  InstantPlayer
//
//  Feed Data stub for the Core filesystem seam (E1-S3, design §3.6 — R2, R7;
//  E2-S1, design §1 — S15).
//

import Foundation

/// Skeleton conformance for the Core filesystem seam. `prepareCollection`
/// answers with a canned collection for wiring tests; the real
/// security-scoped conformance (E2-S1, design §1) ships alongside it in
/// Feed Data.
///
/// Zero I/O: no FileManager, nothing read from disk — every value below is
/// a fixed constant (design §1 table: "returns a canned collection for
/// wiring tests").
nonisolated struct StubMediaFolderRepository: MediaFolderRepository {
    func wiringProbe() async -> String {
        "StubMediaFolderRepository"
    }

    /// Canned collection for wiring tests (S15): constant folder, one
    /// constant video item, starting index 0. The entry action is accepted
    /// (label per the seam contract) and ignored — the canned answer is
    /// fixed.
    func prepareCollection(forEntryAt _: EntryAction) async -> MediaCollection? {
        MediaCollection(
            folderURL: Self.cannedFolderURL,
            items: [Self.cannedItem],
            startIndex: 0,
            capturedAt: Self.cannedCaptureDate
        )
    }

    private static let cannedFolderURL = URL(
        fileURLWithPath: "/InstantPlayer/WiringStub",
        isDirectory: true
    )
    private static let cannedCaptureDate = Date(timeIntervalSinceReferenceDate: 0)
    private static let cannedItem = MediaItem(
        id: Self.cannedFolderURL.appending(path: "canned.mp4"),
        url: Self.cannedFolderURL.appending(path: "canned.mp4"),
        name: "canned.mp4",
        kind: .video
    )
}
