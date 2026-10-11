//
//  InstantPlayerUITestsLaunchTests.swift
//  InstantPlayerUITests
//
//  Created by Guillermo Vertel on 9/10/26.
//

import XCTest

final class InstantPlayerUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The launch smoke test (design §9.4 — R14 of E1-S2): a plain launch
    /// must complete, reach the running state, and present the app's UI
    /// chrome. SCOPE NOTE (AC7, honest caveat): on this toolchain
    /// (macOS 26 / Xcode 26) XCUITest cannot observe the app's window
    /// CONTENT — the external AX tree exposes only the menu bar and
    /// TouchBar (`windows.count == 0` in every role census; full evidence:
    /// docs/specs/e2-s1-entry-media-collection/evidence.md §6.2/§6.3).
    /// The drop-target welcome CONTENT is therefore covered where it is
    /// observable: the S5–S7 state-machine unit tests (seam level) and the
    /// stakeholder functional review in the running app — never claimed
    /// here.
    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()

        // The launch completed (`launch()` returns only after the app has
        // launched and idled) and the app's own UI chrome is exposed — the
        // observable app-level AX surface on this toolchain.
        XCTAssertTrue(
            app.menuBars.firstMatch.waitForExistence(timeout: 10),
            "a plain launch must present the app's menu bar"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
