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

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()

        // E2-S1 (design §9.4; R14 of E1-S2): a plain launch must show the
        // drop-target welcome state — the first meaningful launch assertion.
        XCTAssertTrue(
            app.otherElements["welcome-drop-target"].waitForExistence(timeout: 5),
            "a plain launch must present the drop-target welcome state (S5)"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
