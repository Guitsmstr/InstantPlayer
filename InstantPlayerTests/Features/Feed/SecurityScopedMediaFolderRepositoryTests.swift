//
//  SecurityScopedMediaFolderRepositoryTests.swift
//  InstantPlayerTests
//
//  Entry derivation + collection rules THROUGH the seam (E2-S1, design
//  §9.1–§9.3 — S15: no UI, no running app).
//

import Foundation
@testable import InstantPlayer
import Testing

/// The §9.1–§9.3 suites: the entry-derivation matrix (S1–S5 + the §3.3
/// step-6 edge), the collection rules (S10–S12, S14), the snapshot
/// contract (S13), and fail-open handling — all against the real
/// security-scoped conformance over throwaway fixture folders, through
/// the `MediaFolderRepository` seam only (S15).
@MainActor
struct SecurityScopedMediaFolderRepositoryTests {
    private let repository = SecurityScopedMediaFolderRepository()

    // MARK: - Entry-derivation matrix (§9.3)

    /// S1/S2 — a media-file entry opens its parent folder, positioned at
    /// the entered file.
    @Test func mediaFileEntryOpensParentPositionedAtFile() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "media")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.writeFile("b.mov", into: folder)
        try fixture.writeFile("clip.mp4", into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder.appending(path: "clip.mp4"))
        )
        let opened = try #require(collection)
        #expect(opened.folderURL == folder)
        #expect(opened.items.count == 3)
        #expect(opened.items[opened.startIndex].name == "clip.mp4")
    }

    /// S3 — a folder entry opens the folder itself, at the first item.
    @Test func folderEntryOpensTheFolderAtFirstItem() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "dropfolder")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.writeFile("b.mov", into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        #expect(opened.folderURL == folder)
        #expect(opened.startIndex == 0)
    }

    /// S4 — an unsupported-file entry opens its parent, is itself never
    /// collected, and starts at the first item.
    @Test func unsupportedFileEntryOpensParentWithoutTheFile() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "notes")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.writeFile("notes.txt", bytes: Array("plain".utf8), into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder.appending(path: "notes.txt"))
        )
        let opened = try #require(collection)
        #expect(opened.folderURL == folder)
        #expect(opened.startIndex == 0)
        #expect(!opened.items.contains { $0.name == "notes.txt" })
        #expect(opened.items.map(\.name) == ["a.jpg"])
    }

    /// S5 — an empty folder yields `nil` (welcome, no folder open).
    @Test func emptyFolderYieldsNil() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "empty")

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        guard case .none = collection else {
            Issue.record("S5: an empty folder must yield nil (welcome)")
            return
        }
    }

    /// S5 — a folder with only non-media yields `nil` too.
    @Test func onlyNonMediaFolderYieldsNil() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "justnotes")
        try fixture.writeFile("notes.txt", bytes: Array("plain".utf8), into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        guard case .none = collection else {
            Issue.record("S5: a media-free folder must yield nil (welcome)")
            return
        }
    }

    /// §3.3 step 6 — an entered media file that the collection excludes
    /// (here: hidden) leaves the collection positioned at the first item.
    @Test func enteredButExcludedMediaStartsAtFirstItem() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "hiddenentry")
        try fixture.writeFile("visible.jpg", into: folder)
        try fixture.writeFile(".hidden.mov", into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder.appending(path: ".hidden.mov"))
        )
        let opened = try #require(collection)
        #expect(opened.folderURL == folder)
        #expect(opened.startIndex == 0)
        #expect(opened.items.map(\.name) == ["visible.jpg"])
    }

    // MARK: - Collection rules (§9.1)

    /// S10 — direct children only: media inside a subfolder is absent.
    @Test func subfolderMediaIsNeverCollected() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "shallow")
        try fixture.writeFile("top.mp4", into: folder)
        let nested = try fixture.makeDirectory(named: "sub", in: folder)
        try fixture.writeFile("nested.mp4", into: nested)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        #expect(opened.items.map(\.name) == ["top.mp4"])
        #expect(!opened.items.contains { $0.name == "nested.mp4" })
    }

    /// S11 — the conformance rule rejects misleading entries REGARDLESS of
    /// file name: `clip.mp4.txt` (declared text), a folder named
    /// `folder.mp4`, a fifo named `pipe.mp4`, hidden `._clip.mp4` and
    /// `.hidden.mp4` — while `a.jpg`/`b.mov` are accepted. No extension
    /// list, no name parsing.
    @Test func conformanceRuleRejectsMisleadingNamesRegardlessOfFileName() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "spoof")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.writeFile("b.mov", into: folder)
        try fixture.writeFile("clip.mp4.txt", bytes: Array("plain".utf8), into: folder)
        try fixture.makeDirectory(named: "folder.mp4", in: folder)
        try fixture.makeFifo(named: "pipe.mp4", in: folder)
        try fixture.writeFile("._clip.mp4", into: folder)
        try fixture.writeFile(".hidden.mp4", into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        #expect(Set(opened.items.map(\.name)) == Set(["a.jpg", "b.mov"]))
    }

    /// S12 — boundary enforcement: every excluded entry appears in NO item
    /// of the collection.
    @Test func excludedEntriesAppearInNoItem() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "boundary")
        try fixture.writeFile("a.jpg", into: folder)
        let excluded = [
            "clip.mp4.txt", "folder.mp4", "pipe.mp4", "._clip.mp4", ".hidden.mp4", "notes.txt",
        ]
        try fixture.writeFile("notes.txt", bytes: Array("plain".utf8), into: folder)
        try fixture.writeFile("clip.mp4.txt", bytes: Array("plain".utf8), into: folder)
        try fixture.makeDirectory(named: "folder.mp4", in: folder)
        try fixture.makeFifo(named: "pipe.mp4", in: folder)
        try fixture.writeFile("._clip.mp4", into: folder)
        try fixture.writeFile(".hidden.mp4", into: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        #expect(!opened.items.isEmpty)
        for name in excluded {
            #expect(
                !opened.items.contains { $0.name == name },
                "S12: excluded entry \(name) must appear in no item"
            )
        }
    }

    /// S14 — items order equals the scan's enumeration order; no sorting
    /// is applied (orderings are E4-S1's).
    @Test func itemsPreserveEnumerationOrderWithoutSorting() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "order")
        let names = [
            "m07.mp4", "m03.mp4", "m11.mov", "m01.jpg",
            "m09.mp4", "m05.mov", "m13.jpg", "m02.mp4",
        ]
        for name in names {
            try fixture.writeFile(name, into: folder)
        }

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        let rawOrder = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
        .map(\.lastPathComponent)
        .filter { names.contains($0) }
        #expect(opened.items.map(\.name) == rawOrder)
    }

    // MARK: - Snapshot & fail-open (§9.1)

    /// S13 — snapshot/staleness: after open the collection never changes;
    /// disk drift shows only in a fresh entry action.
    @Test func collectionIsSnapshotFreshEntryRecollects() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "snapshot")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.writeFile("b.mov", into: folder)

        let action = EntryAction(enteredURL: folder)
        let first = try #require(
            await repository.prepareCollection(forEntryAt: action)
        )
        #expect(first.items.count == 2)

        // Disk drifts after open: one addition, one removal.
        try fixture.writeFile("c.mp4", into: folder)
        try FileManager.default.removeItem(at: folder.appending(path: "a.jpg"))

        // The snapshot is unchanged — no watching, no re-scan on read (S13).
        #expect(first.items.count == 2)
        #expect(first.items.contains { $0.name == "a.jpg" })
        #expect(!first.items.contains { $0.name == "c.mp4" })

        // A fresh entry action re-collects the drifted disk.
        let second = try #require(
            await repository.prepareCollection(forEntryAt: action)
        )
        #expect(second.items.count == 2)
        #expect(second.items.contains { $0.name == "c.mp4" })
        #expect(!second.items.contains { $0.name == "a.jpg" })
        #expect(second.capturedAt >= first.capturedAt)
    }

    /// Fail-open (§5.3) — a broken symlink (unreadable resource values)
    /// skips that entry and keeps the folder's other media.
    @Test func brokenSymlinkSkipsEntryAndKeepsFolderMedia() async throws {
        let fixture = MediaFixture()
        let folder = try fixture.makeDirectory(named: "failopen")
        try fixture.writeFile("a.jpg", into: folder)
        try fixture.makeBrokenSymlink(named: "gone.mov", to: "missing-target.mov", in: folder)

        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: folder)
        )
        let opened = try #require(collection)
        #expect(opened.items.map(\.name) == ["a.jpg"])
        #expect(!opened.items.contains { $0.name == "gone.mov" })
    }

    /// Fail-open (§5.3) — an unreadable/missing entered path yields `nil`
    /// (welcome), never a crash.
    @Test func nonexistentEnteredPathYieldsNil() async {
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "instantplayer-missing-\(UUID().uuidString)")
        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: missing)
        )
        guard case .none = collection else {
            Issue.record("a nonexistent entered path must yield nil (welcome, S5)")
            return
        }
    }

    /// Untrusted input (§8.3) — only file URLs are accepted at the seam.
    @Test func nonFileURLYieldsNil() async throws {
        let remote = try #require(URL(string: "https://example.com/clip.mp4"))
        let collection = await repository.prepareCollection(
            forEntryAt: EntryAction(enteredURL: remote)
        )
        guard case .none = collection else {
            Issue.record("a non-file URL must be rejected at the Data edge (§8.3)")
            return
        }
    }
}
