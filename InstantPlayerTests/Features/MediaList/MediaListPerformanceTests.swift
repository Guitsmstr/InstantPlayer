//
//  MediaListPerformanceTests.swift
//  InstantPlayerTests
//
//  The RNF-02 list budgets through the selection machine + row
//  projection, measured (E5-S1, design §7(1)–(3), §7(7) — S15).
//

@testable import InstantPlayer
import XCTest

/// The §7 budgets, measured from tooling:
///
/// - **View switch (§7(1)):** the switch path (state flip + row
///   projection) stays ≤ 100 ms p95 at 10 000 items and ≤ 300 ms p95 at
///   the degenerate 50 000 extreme. The measured unit is the §7(1)
///   verification note's "view-model path (state flip + row projection)":
///   one wholesale snapshot application (the row projection a switch
///   presents) plus the presentation flip in both directions — the pure
///   SwiftUI layout share is functional-review territory.
/// - **Selection change (§7(3)):** single/⌘-click (O(1)) and ⇧ range ops
///   (worst-case full-length extend) apply within one frame — ≤ 16 ms in
///   one main-actor turn.
/// - **Arrow repeat (§7(3)):** auto-repeat builds no backlog — each step
///   is one O(1) state write; at the boundary the clamp is idempotent, so
///   a held arrow at the last row is repeated idempotent no-ops, and a
///   30-key burst fits inside one repeat interval.
///
/// XCTest `measure` is the design's one deliberate Swift Testing exception
/// (the E3-S2 §8 pattern); budget assertions use the E2-S2 §8(1)
/// nearest-rank p95 over sampled passes, and every measured number is
/// appended to a throwaway scratch file (never committed) so task 11
/// records story evidence from tooling. The per-row `body` budget
/// (§7(2), ≤ 1 ms) has no unit-reachable rendering cost — a unit test
/// cannot mount SwiftUI rows — so it is carried by the row's
/// construction (two O(1) checks + one `Text`) and functional review.
///
/// Two house rules keep the runner alive here. First, the class is
/// `nonisolated` on purpose (the lesson recorded on
/// `SeekLandingPerformanceTests`). Second — this file's own lesson — a
/// `measure` block must capture **only `self`**: a `@MainActor`-isolated
/// view model captured directly in the ObjC-bridged block over-releases
/// at scope exit and aborts the runner, so every block calls one
/// `nonisolated` run-one helper that reads instance state and hops to the
/// main actor through `MainActor.assumeIsolated` (XCTest executes test
/// methods on the main thread; the helper states that guarantee
/// explicitly). Generated fixtures are 10k/50k synthetic `MediaItem`s —
/// URLs and names are pure values under a throwaway temporary directory
/// (no files are created or touched — the display-only contract, S14,
/// holds in tests too).
final class MediaListPerformanceTests: XCTestCase {
    /// The budgeted size (design §7: collections up to 10 000 items).
    private static let typicalCount = 10000

    /// The degenerate extreme's size (design §7(1): up to 50 000).
    private static let degenerateCount = 50000

    /// The fixture pair and view models of the running method — instance
    /// state so the `measure` blocks capture only `self` (the class
    /// comment's over-release lesson).
    private var snapshots: [MediaCollection] = []
    private var switchModel: MediaListViewModel?
    private var selectionModel: MediaListViewModel?
    private var arrowModel: MediaListViewModel?
    private var switchMeasureIteration = 0

    // MARK: §7(1) — the view-switch budget at 10k (S15)

    /// ≤ 100 ms p95 at 10 000 items: one wholesale snapshot application
    /// (row projection) plus both presentation flips, per pass.
    func testViewSwitchBudgetAtTenThousandItems() {
        recordEvidenceHeader("10k switch budget (design §7(1))")
        snapshots = Self.makeSnapshotPair(count: Self.typicalCount)
        switchModel = onMainActor { MediaListViewModel() }

        // Sampled passes: nearest-rank p95 over 20 (the §7(1) budget).
        guard let model = switchModel else { return }
        var passTimes = [Double]()
        for pass in 0 ..< 20 {
            let snapshot = snapshots[pass % 2]
            passTimes.append(
                timedTurn { self.applyAndFlip(model: model, snapshot: snapshot) }
            )
        }
        assertBudget(
            passTimes,
            limit: 0.100,
            name: "switch pass (apply + both flips, §7(1))",
            budget: "100 ms p95"
        )

        // Tooling evidence: the same path under XCTest `measure` (design
        // §7(7)) — 10 recorded iterations, snapshots alternating per pass
        // so every `apply` is a real wholesale projection (S18's marker).
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        measure(options: options) {
            let elapsed = self.runOneSwitchMeasureIteration()
            Self.recordEvidence("switch measure iteration: \(Self.format(ms: [elapsed]))")
        }
    }

    // MARK: §7(3) — the selection-change budget at 10k (one main-actor turn)

    /// ≤ 16 ms per selection change at 10 000 items: single click and
    /// ⌘-click (O(1)) and the ⇧ worst case (full-length range extend),
    /// each sampled per op — the whole model share of one main-actor turn.
    func testSelectionChangeBudgetAtTenThousandItems() {
        recordEvidenceHeader("10k selection-change budget (design §7(3))")
        snapshots = Self.makeSnapshotPair(count: Self.typicalCount)
        selectionModel = onMainActor { MediaListViewModel() }
        onMainActor {
            self.selectionModel?.apply(collection: self.snapshots[0])
            self.selectionModel?.togglePresentation()
        }
        let rows = snapshots[0].items.map(\.id)
        let lastRow = rows[rows.count - 1]

        // Single click (S6 — O(1)): selection = {R}, anchor = lead = R.
        var singleClickTimes = [Double]()
        for row in rows[0 ..< 20] {
            singleClickTimes.append(timedTurn { selectionModel?.selectRow(row) })
        }
        assertTurnBudget(singleClickTimes, "single click (S6)")

        // ⌘-click (S7 — O(1)): membership flip, the rest preserved.
        var commandClickTimes = [Double]()
        for row in rows[0 ..< 20] {
            commandClickTimes.append(timedTurn { selectionModel?.toggleRow(row) })
        }
        assertTurnBudget(commandClickTimes, "command click (S7)")

        // ⇧-click (S8 — O(range), worst case: anchor at the first row,
        // target at the last — the full 10k range rebuilt per op).
        var shiftClickTimes = [Double]()
        for _ in 0 ..< 20 {
            onMainActor { selectionModel?.selectRow(rows[0]) }
            shiftClickTimes.append(timedTurn { selectionModel?.extendToRow(lastRow) })
        }
        assertTurnBudget(shiftClickTimes, "shift-click full range (S8)")

        // Empty-space click (S10 — O(1)): clear.
        var clearTimes = [Double]()
        for _ in 0 ..< 20 {
            clearTimes.append(timedTurn { selectionModel?.clearSelection() })
        }
        assertTurnBudget(clearTimes, "empty-space clear (S10)")

        // Tooling evidence: one compound selection turn under `measure`
        // (select → full-range extend → ⌘-flip → clear).
        measure {
            let elapsed = self.runOneSelectionMeasureIteration()
            Self.recordEvidence("selection compound measure iteration: \(Self.format(ms: [elapsed]))")
        }
    }

    // MARK: §7(3) — the arrow-repeat step path at 10k (no backlog)

    /// The step path at 10 000 items: real one-row steps and
    /// boundary-clamped idempotent repeats are each one O(1) state write
    /// (≤ 16 ms), and a 30-key held-arrow burst (30 keys/s) completes
    /// within a single repeat interval (~33 ms) — no backlog.
    func testArrowRepeatStepPathAtTenThousandItems() {
        recordEvidenceHeader("10k arrow-repeat step path (design §7(3))")
        snapshots = Self.makeSnapshotPair(count: Self.typicalCount)
        arrowModel = onMainActor { MediaListViewModel() }
        onMainActor {
            self.arrowModel?.apply(collection: self.snapshots[0])
            self.arrowModel?.togglePresentation()
        }
        let rows = snapshots[0].items.map(\.id)
        let lastRow = rows[rows.count - 1]

        // Real steps through the middle of the row array: ↓ walks
        // adjacent rows (each collapses the selection to the lead).
        var stepTimes = [Double]()
        for index in 1 ..< 21 {
            onMainActor { arrowModel?.selectRow(rows[index - 1]) }
            stepTimes.append(timedTurn { arrowModel?.moveSelection(.down) })
        }
        assertTurnBudget(stepTimes, "arrow step (S9)")

        // Boundary clamps: with the lead at the last row, ↓ repeats are
        // idempotent no-ops (no wrap — the D38 repeat-parity pattern).
        onMainActor { arrowModel?.selectRow(lastRow) }
        var clampTimes = [Double]()
        for _ in 0 ..< 20 {
            clampTimes.append(timedTurn { arrowModel?.moveSelection(.down) })
        }
        assertTurnBudget(clampTimes, "boundary-clamped repeat (S9)")

        // ⇧-arrow extension steps (anchor fixed at the first row): the
        // lead walks and each step reselects the anchor…lead range — the
        // O(range) keyboard twin of the ⇧-click.
        onMainActor { arrowModel?.selectRow(rows[0]) }
        var extendStepTimes = [Double]()
        for _ in 0 ..< 20 {
            extendStepTimes.append(timedTurn { arrowModel?.extendSelection(.down) })
        }
        assertTurnBudget(extendStepTimes, "shift-arrow extend step (S9)")

        // No-backlog burst: 30 held-arrow repeats (the top auto-repeat
        // rate, design §7(3)) at the boundary — the whole burst must fit
        // inside ONE repeat interval (~33 ms at 30 keys/s), or repeats
        // would queue up.
        let burstStart = Date()
        onMainActor {
            for _ in 0 ..< 30 {
                self.arrowModel?.moveSelection(.down)
            }
        }
        let burstElapsed = Date().timeIntervalSince(burstStart)
        Self.recordEvidence(
            "30-key boundary burst: \(Self.format(ms: [burstElapsed])) (one 30 keys/s repeat interval ≈ 33 ms)"
        )
        XCTAssertLessThan(
            burstElapsed,
            0.033,
            "the 30-key boundary burst must fit one repeat interval — no backlog (design §7(3))"
        )

        // Tooling evidence: one clamped repeat under `measure`.
        measure {
            let elapsed = self.runOneClampMeasureIteration()
            Self.recordEvidence("clamped repeat measure iteration: \(Self.format(ms: [elapsed]))")
        }
    }

    /// ≤ 300 ms p95 at the degenerate 50 000 extreme (design §7(1) —
    /// reviewed, not a gate tripwire like the 10k block above).
    func testViewSwitchBudgetAtFiftyThousandDegenerateExtreme() {
        recordEvidenceHeader("50k degenerate extreme (design §7(1))")
        snapshots = Self.makeSnapshotPair(count: Self.degenerateCount)
        switchModel = onMainActor { MediaListViewModel() }

        guard let model = switchModel else { return }
        var passTimes = [Double]()
        for pass in 0 ..< 20 {
            let snapshot = snapshots[pass % 2]
            passTimes.append(
                timedTurn { self.applyAndFlip(model: model, snapshot: snapshot) }
            )
        }
        assertBudget(
            passTimes,
            limit: 0.300,
            name: "switch pass at 50k (apply + both flips, §7(1))",
            budget: "300 ms p95"
        )

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(options: options) {
            let elapsed = self.runOneSwitchMeasureIteration()
            Self.recordEvidence("50k switch measure iteration: \(Self.format(ms: [elapsed]))")
        }
    }

    // MARK: Run-one helpers (one call per measure iteration — see the class comment)

    /// One measured switch pass (task 7.2's "state flip + row
    /// projection"): apply the snapshot (the wholesale projection), flip
    /// to the list, flip back (S5's round trip; the flips never touch the
    /// selection — S18 structural). Snapshots alternate per iteration so
    /// every `apply` is a real wholesale swap (S18's capturedAt marker).
    private nonisolated func runOneSwitchMeasureIteration() -> Double {
        guard let model = switchModel else {
            assertionFailure("the switch-budget method must have built its model")
            return 0
        }
        let snapshot = snapshots[switchMeasureIteration % 2]
        switchMeasureIteration += 1
        let start = Date()
        MainActor.assumeIsolated {
            self.applyAndFlip(model: model, snapshot: snapshot)
        }
        return Date().timeIntervalSince(start)
    }

    /// One measured compound selection turn: select → full-range extend →
    /// ⌘-flip → clear (the §7(3) path mix).
    private nonisolated func runOneSelectionMeasureIteration() -> Double {
        let rows = snapshots[0].items.map(\.id)
        let start = Date()
        MainActor.assumeIsolated {
            self.selectionModel?.selectRow(rows[0])
            self.selectionModel?.extendToRow(rows[rows.count - 1])
            self.selectionModel?.toggleRow(rows[1])
            self.selectionModel?.clearSelection()
        }
        return Date().timeIntervalSince(start)
    }

    /// One measured boundary-clamped repeat: at the last row, ↓ is an
    /// idempotent no-op (the D38 repeat-parity pattern).
    private nonisolated func runOneClampMeasureIteration() -> Double {
        let start = Date()
        MainActor.assumeIsolated {
            self.arrowModel?.moveSelection(.down)
        }
        return Date().timeIntervalSince(start)
    }

    // MARK: Main-actor turns (the isolation guarantee, stated explicitly)

    /// The measured compound of one switch pass: apply + both flips (the
    /// main-actor body of the switch iterations).
    @MainActor
    private func applyAndFlip(model: MediaListViewModel, snapshot: MediaCollection) {
        model.apply(collection: snapshot)
        model.togglePresentation()
        model.togglePresentation()
    }

    /// Runs one synchronous body on the main actor and returns its result.
    /// XCTest executes test methods on the main thread — the actor the
    /// view models live on — and `assumeIsolated` states that guarantee.
    private func onMainActor<T>(_ body: @MainActor () -> T) -> T {
        MainActor.assumeIsolated(body)
    }

    /// The timed form: wall time of one synchronous main-actor turn, in
    /// seconds — the unit of the §7(3) per-turn budgets.
    private func timedTurn(_ body: @MainActor () -> Void) -> Double {
        let start = Date()
        onMainActor(body)
        return Date().timeIntervalSince(start)
    }

    /// The p95 budget assertion for sampled passes.
    private func assertBudget(_ times: [Double], limit: Double, name: String, budget: String) {
        let p95 = Self.nearestRankP95(times)
        Self.recordEvidence(
            "\(name): \(Self.format(ms: times)) — p95 \(Self.format(ms: [p95])) (budget \(budget))"
        )
        XCTAssertLessThan(
            p95,
            limit,
            "\(budget) (design §7) violated: \(name)"
        )
    }

    /// The per-change budget (≤ 16 ms, one frame — §7(3)): nearest-rank
    /// p95 over the sampled turns.
    private func assertTurnBudget(_ times: [Double], _ name: String) {
        assertBudget(times, limit: 0.016, name: name, budget: "16 ms p95")
    }

    // MARK: Evidence capture (task 7.3 → task 11: from tooling, never memory)

    /// The scratch file the measured numbers land in — the app cache
    /// directory (resolves through the sandbox container when present).
    /// Append-only, with a timestamped header per method so task 11 quotes
    /// the current gate run's block. Test-only scratch: timing numbers,
    /// never committed (the E2-S2 §8 pattern).
    private static var evidenceFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("e5s1-list-budget-evidence.txt")
    }

    /// Opens one timestamped evidence block (per method — the file
    /// accumulates across gate runs; the last block is current).
    private func recordEvidenceHeader(_ title: String) {
        Self.recordEvidence("--- \(title) @ \(Date()) ---")
    }

    /// Appends one measured line to the scratch evidence file (best-effort:
    /// a failed write must not fail the measurement itself).
    private static func recordEvidence(_ line: String) {
        let url = evidenceFile
        if let handle = FileHandle(forWritingAtPath: url.path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write((line + "\n").data(using: .utf8) ?? Data())
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func format(ms times: [Double]) -> String {
        times.map { String(format: "%.3f", $0 * 1000) }.joined(separator: ", ")
    }

    // MARK: Fixtures & statistics

    /// A synthetic snapshot pair of `count` items: names and kinds
    /// alternate (video/image), order is the snapshot order, and the two
    /// values differ only in `capturedAt` — the snapshot marker that makes
    /// every `apply` a real wholesale swap (S18's reset point). The
    /// markers are fixed epoch offsets, not two `Date()` calls: consecutive
    /// `Date()` values can be equal at clock granularity, which would turn
    /// measured passes into no-ops.
    private static func makeSnapshotPair(count: Int) -> [MediaCollection] {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "e5-s1-perf-\(count)-\(UUID().uuidString)", directoryHint: .isDirectory)
        let items = (0 ..< count).map { index in
            let name = "item-\(String(format: "%06d", index)).\(index.isMultiple(of: 2) ? "mp4" : "png")"
            let fileURL = folder.appending(path: name)
            return MediaItem(
                id: fileURL,
                url: fileURL,
                name: name,
                kind: index.isMultiple(of: 2) ? .video : .image
            )
        }
        return [
            MediaCollection(
                folderURL: folder,
                items: items,
                startIndex: 0,
                capturedAt: Date(timeIntervalSince1970: 0)
            ),
            MediaCollection(
                folderURL: folder,
                items: items,
                startIndex: 0,
                capturedAt: Date(timeIntervalSince1970: 1)
            ),
        ]
    }

    /// The nearest-rank p95 (the E2-S2 §8(1) convention):
    /// sorted[⌈0.95 × n⌉ − 1].
    private static func nearestRankP95(_ samples: [Double]) -> Double {
        let sorted = samples.sorted()
        let rank = Int((0.95 * Double(sorted.count)).rounded(.up))
        return sorted[rank - 1]
    }
}
