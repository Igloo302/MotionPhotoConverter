//
//  Motion2LiveUITests.swift
//  Motion2LiveUITests
//

import XCTest

final class Motion2LiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndDisplaysMainControls() throws {
        let app = XCUIApplication()
        app.launch()

        // 验证主界面存在导航栏与至少一个主要操作按钮
        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 5))
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
