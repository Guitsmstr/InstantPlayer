//
//  MediaCollectionPerformanceTests.swift
//  InstantPlayerTests
//
//  Entry-time budget, measured (E2-S1, design §7.1 — RNF-02).
//

@testable import InstantPlayer
import XCTest

/// The §7.1 entry-time budget, measured from tooling: 1,000 direct
/// children collected within 1 s wall time; a typical folder (≤200
/// children) within 250 ms. The budget covers derivation + scan +
/// classification — the security-scope handshake is kernel-side and
/// excluded. XCTest `measure` is the design's one deliberate Swift
/// Testing exception (§4.2); its numbers are recorded as story evidence
/// (task 7).
final class MediaCollectionPerformanceTests: XCTestCase {
    func testEntryBudgetForTypicalAndThousandEntryFolders() {
        let fixture = MediaFixture()
        let repository = SecurityScopedMediaFolderRepository()

        // Typical folder (≤200 children) within 250 ms — design §7.1.
        guard let typicalFolder = try? fixture.makeDirectory(named: "typical", fileCount: 200) else {
            XCTFail("typical fixture folder must build")
            return
        }
        assertSinglePass(
            repository: repository,
            folder: typicalFolder,
            staysUnderSeconds: 0.25,
            budgetName: "250 ms typical-folder budget"
        )

        // 1,000 direct children within 1 s — design §7.1.
        guard let largeFolder = try? fixture.makeDirectory(named: "large", fileCount: 1000) else {
            XCTFail("large fixture folder must build")
            return
        }
        assertSinglePass(
            repository: repository,
            folder: largeFolder,
            staysUnderSeconds: 1.0,
            budgetName: "1 s thousand-entry budget"
        )

        // Tooling evidence: measured over iterations for task 7's record.
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        let action = EntryAction(enteredURL: largeFolder)
        measure(options: options) {
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                _ = await repository.prepareCollection(forEntryAt: action)
                done.signal()
            }
            _ = done.wait(timeout: .now() + 60)
        }
    }

    /// Deterministic regression catch: one cold pass must stay under the
    /// budget (the measure block reports trends; this asserts the bound).
    private func assertSinglePass(
        repository: SecurityScopedMediaFolderRepository,
        folder: URL,
        staysUnderSeconds budget: Double,
        budgetName: String
    ) {
        let action = EntryAction(enteredURL: folder)
        let start = Date()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            _ = await repository.prepareCollection(forEntryAt: action)
            done.signal()
        }
        _ = done.wait(timeout: .now() + 60)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, budget, "\(budgetName) violated (design §7.1)")
    }
}
