import XCTest

final class ToolboxUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(onboarded: Bool = true) {
        app.launchArguments = ["-hasCompletedOnboarding", onboarded ? "YES" : "NO"]
        app.launch()
    }

    func testOnboardingFlow() {
        launch(onboarded: false)
        XCTAssertTrue(app.staticTexts["Your everyday tools."].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Private by design."].waitForExistence(timeout: 3))
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
    }

    func testLaunchShowsHome() {
        launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Files"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testTabNavigation() {
        launch()
        app.tabBars.buttons["Files"].tap()
        XCTAssertTrue(app.navigationBars["Files"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testSearchFiltersTools() {
        launch()
        let field = app.textFields["Search tools..."]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("pdf")
        XCTAssertTrue(toolButton("Compress PDF").waitForExistence(timeout: 3))
        XCTAssertFalse(toolButton("Resize Image").exists)
    }

    func testOpenQRScanner() {
        launch()
        open("QR")
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5)
                      || app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testOpenOCR() {
        launch()
        open("OCR")
        XCTAssertTrue(app.buttons["Scan with Camera"].waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    private func toolButton(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func open(_ title: String) {
        let button = toolButton(title)
        var tries = 0
        while !(button.exists && button.isHittable) && tries < 5 {
            app.swipeUp()
            tries += 1
        }
        button.tap()
    }
}
