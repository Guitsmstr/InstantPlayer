//
//  StubMediaFolderRepository.swift
//  InstantPlayer
//
//  Feed Data stub for the Core filesystem seam (E1-S3, design §3.6 — R2, R7).
//

/// Skeleton conformance for the Core filesystem seam. The real
/// security-scoped conformance (R12) arrives with the Feed folder-loading
/// story — Feed is the consumer that will own it.
struct StubMediaFolderRepository: MediaFolderRepository {
    func wiringProbe() async -> String {
        "StubMediaFolderRepository"
    }
}
