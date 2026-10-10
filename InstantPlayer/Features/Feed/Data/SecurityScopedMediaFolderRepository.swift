//
//  SecurityScopedMediaFolderRepository.swift
//  InstantPlayer
//
//  Feed Data real conformance for the Core filesystem seam
//  (E2-S1, design §1, §3.3, §5, §6, §8 — S1–S4, S8–S14).
//

import Foundation
import UniformTypeIdentifiers

/// The real `MediaFolderRepository`: derives the one folder to open per
/// S1–S4, collects its direct-children media per S10–S12/S14, and holds the
/// security-scoped session per S8–S9 — all behind the seam.
///
/// An `actor` on purpose (design §11: D8's trigger): this story introduces
/// mutable session state shared across isolation domains, and the actor's
/// executor is the boundary that keeps entry-time enumeration and type
/// resolution OFF the main thread (design §7.2 — the project defaults to
/// MainActor isolation). The active session's scoped URLs are the only
/// mutable state; the `@MainActor` view model receives only the finished
/// value. No logging exists in this conformance (§8: no paths, no names).
actor SecurityScopedMediaFolderRepository: MediaFolderRepository {
    func wiringProbe() async -> String {
        "SecurityScopedMediaFolderRepository"
    }

    func prepareCollection(forEntryAt entryAction: EntryAction) async -> MediaCollection? {
        // A new entry action supersedes the previous open session
        // (design §8.1): release it before anything else.
        endOpenSession()

        // Untrusted input (§8.3): file URLs only, standardized before use;
        // every derivation below is by URL operations — never string path
        // concatenation (no `..` traversal surface).
        guard entryAction.enteredURL.isFileURL else { return nil }
        let enteredURL = entryAction.enteredURL.standardizedFileURL

        // Derivation step 1 (§3.3): classify the entered URL from its own
        // resource values. A symlink, package, or non-regular entry is
        // file-shaped — its own target is never followed. An unreadable or
        // missing entered URL means no folder can be derived → welcome
        // (fail-open, §5.3).
        guard let enteredValues = try? enteredURL.resourceValues(forKeys: Self.resourceKeys) else {
            return nil
        }

        // Derivation steps 2–4 (§3.3): folder entry → the folder itself
        // (S3); media file → its parent, positioned at the file (S1, S2);
        // unsupported file → its parent, never collected, first item (S4).
        let isFolderEntry = enteredValues.isDirectory == true
            && enteredValues.isSymbolicLink != true
            && enteredValues.isPackage != true
        let folderURL = isFolderEntry ? enteredURL : enteredURL.deletingLastPathComponent()
        let enteredIsMedia = MediaTypeClassifier.mediaKind(of: enteredValues) != nil
        let startCandidate: URL? = (isFolderEntry || !enteredIsMedia) ? nil : enteredURL

        // S8–S9 (design §8.1): scope this entry's pair — the entered URL
        // and the derived folder. Belt-and-braces: implicit scopes make a
        // redundant start on an already-granted URL harmless.
        beginSession(enteredURL: enteredURL, folderURL: folderURL)

        // One shallow scan of the direct children (S10, S14). Enumeration
        // failure is the only folder-level failure → welcome (§5.3).
        let items: [MediaItem]
        do {
            items = try scan(folderURL: folderURL)
        } catch {
            return nil
        }

        // An empty result is never a collection — welcome (S5, §3.3 step 5).
        guard !items.isEmpty else { return nil }

        // Starting-item rule (§3.3 step 6): the entered file's index when
        // that file is part of the collection, otherwise the first item
        // (covers e.g. an entered-but-excluded media file).
        let startIndex = startCandidate.flatMap { candidate in
            items.firstIndex(where: { $0.id == candidate })
        } ?? 0

        return MediaCollection(
            folderURL: folderURL,
            items: items,
            startIndex: startIndex,
            capturedAt: Date()
        )
    }

    // MARK: - Security-scoped session (S8–S9, design §8.1)

    /// The active open session's scoped URLs — the actor's only mutable
    /// state. Conformance-internal by contract (design §2): no start/stop
    /// members leak onto the seam.
    private var activeSessionURLs: [URL] = []

    /// Releases the current open session. Called when a new entry action
    /// begins; process exit releases whatever is still held (S9). No
    /// bookmarks, no persistence anywhere (S9 non-goal).
    private func endOpenSession() {
        for url in activeSessionURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSessionURLs = []
    }

    /// Starts this entry's scoped access on the entered URL and the derived
    /// folder (S8). Only URLs that actually grant scope are tracked, so
    /// `stop` is called exactly where `start` succeeded.
    private func beginSession(enteredURL: URL, folderURL: URL) {
        var granted: [URL] = []
        for url in [enteredURL, folderURL] {
            if url.startAccessingSecurityScopedResource() {
                granted.append(url)
            }
        }
        activeSessionURLs = granted
    }

    // MARK: - Scan (S10, S13, S14 — design §5.1)

    /// The exclusion/judgment keys (design §5.1). A `Set` is what
    /// `URL.resourceValues(forKeys:)` takes; the scan prefetch passes the
    /// same keys as an array to `contentsOfDirectory`.
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isPackageKey,
        .isSymbolicLinkKey,
        .isRegularFileKey,
        .isHiddenKey,
        .contentTypeKey,
    ]

    /// One shallow enumeration of the folder's direct children — never
    /// recursive (S10) — with resource-value prefetch. Enumeration order is
    /// preserved as returned; no sorting is applied (S14).
    ///
    /// Fail-open per entry (§5.3): unreadable resource values, broken
    /// symlinks, and races with deletions skip that entry and continue —
    /// only enumeration itself failing (unreadable/missing folder) throws.
    private func scan(folderURL: URL) throws -> [MediaItem] {
        let children = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: []
        )
        var items: [MediaItem] = []
        for childURL in children {
            guard let values = try? childURL.resourceValues(forKeys: Self.resourceKeys),
                  let kind = MediaTypeClassifier.mediaKind(of: values)
            else { continue }
            // Name = display only (§8.3): captured at open, never parsed,
            // never logged.
            items.append(
                MediaItem(
                    id: childURL,
                    url: childURL,
                    name: childURL.lastPathComponent,
                    kind: kind
                )
            )
        }
        return items
    }
}
