//
//  MediaFixture.swift
//  InstantPlayerTests
//
//  Throwaway fixture builder for the seam suites (E2-S1, design §9.1).
//

import Darwin
import Foundation

/// Builds throwaway fixture folders under
/// `FileManager.default.temporaryDirectory/<UUID>/` and removes the tree
/// when the fixture dies (deinit teardown — design §9.1).
///
/// Determinism (§9.1): payloads are fixed byte constants typed by
/// EXTENSION — the honest declared-type contract of §5.2 (content bytes
/// are never sniffed; nothing here needs to be playable). A 1×1 PNG for
/// `.png`, a minimal JPEG (SOI/APP0/EOI) constant for `.jpg`, a minimal
/// ISO-BMFF `ftyp` stub for `.mp4`/`.mov`.
final class MediaFixture {
    let root: URL
    private let fileManager = FileManager.default

    init() {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: root)
    }

    /// Empty subfolder under the fixture root.
    @discardableResult
    func makeDirectory(named name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Subfolder inside an existing fixture folder (e.g. a subfolder
    /// holding media that must NOT be collected, S10).
    @discardableResult
    func makeDirectory(named name: String, in parent: URL) throws -> URL {
        let url = parent.appending(path: name, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Folder pre-populated with `fileCount` media files (perf fixtures).
    @discardableResult
    func makeDirectory(named name: String, fileCount: Int) throws -> URL {
        let folder = try makeDirectory(named: name)
        for index in 0 ..< fileCount {
            try writeFile("clip-\(index).mp4", into: folder)
        }
        return folder
    }

    /// Writes a file with the fixture's deterministic typed bytes.
    @discardableResult
    func writeFile(_ name: String, bytes: [UInt8]? = nil, into folder: URL? = nil) throws -> URL {
        let url = (folder ?? root).appending(path: name)
        try Data(bytes ?? Self.bytes(for: name)).write(to: url, options: .atomic)
        return url
    }

    /// Broken symlink (destination does not exist) — the fail-open case.
    func makeBrokenSymlink(named name: String, to missingTarget: String, in folder: URL) throws {
        try fileManager.createSymbolicLink(
            at: folder.appending(path: name),
            withDestinationURL: folder.appending(path: missingTarget)
        )
    }

    /// FIFO — a non-regular special file (S11 exclusion set).
    struct FifoCreationFailure: Error {}

    func makeFifo(named name: String, in folder: URL) throws {
        let path = folder.appending(path: name).path
        guard mkfifo(path, S_IRUSR | S_IWUSR) == 0 else {
            throw FifoCreationFailure()
        }
    }

    /// Fixed typed bytes per extension (§9.1 determinism).
    static func bytes(for name: String) -> [UInt8] {
        switch name.lowercased() {
        case let lowercased where lowercased.hasSuffix(".jpg"):
            jpeg
        case let lowercased where lowercased.hasSuffix(".png"):
            png1x1
        default:
            ftyp
        }
    }

    /// Canonical 1×1 PNG.
    static let png1x1: [UInt8] = [
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

    /// Minimal JPEG constant (SOI/APP0 marker … EOI) — declared-type bytes.
    static let jpeg: [UInt8] = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
        0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
        0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]

    /// Minimal ISO-BMFF `ftyp` stub (size/'ftyp'/'isom'/ver/'isom'/'mp41') —
    /// the declared-type carrier; bytes need not be playable (§9.1).
    static let ftyp: [UInt8] = [
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D, 0x6D, 0x70, 0x34, 0x31,
    ]
}
