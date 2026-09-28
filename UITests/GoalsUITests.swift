import XCTest

final class GoalsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testGoalsCanBeSetAndRemovedIndependently() {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "body", "-uiTesting"]
        app.launch()

        let openGoals = app.buttons["openGoals"]
        XCTAssertTrue(openGoals.waitForExistence(timeout: 10))
        openGoals.tap()

        let weight = app.switches["goal-weight-enabled"]
        let bodyFat = app.switches["goal-bodyFat-enabled"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        let weightValue = app.textFields["goal-weight-lower"]
        XCTAssertTrue(weightValue.waitForExistence(timeout: 5))
        weightValue.tap()
        weightValue.typeText("80")

        bodyFat.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        let bodyFatValue = app.textFields["goal-bodyFat-lower"]
        XCTAssertTrue(bodyFatValue.waitForExistence(timeout: 5))
        bodyFatValue.tap()
        bodyFatValue.typeText("15")
        app.buttons["saveGoals"].tap()

        XCTAssertTrue(openGoals.waitForExistence(timeout: 5))
        openGoals.tap()
        XCTAssertTrue(app.textFields["goal-weight-lower"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["goal-bodyFat-lower"].exists)
        XCTAssertEqual(app.textFields["goal-weight-lower"].value as? String, "80")
        XCTAssertEqual(app.textFields["goal-bodyFat-lower"].value as? String, "15")

        app.switches["goal-weight-enabled"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        app.buttons["saveGoals"].tap()
        openGoals.tap()
        XCTAssertFalse(app.textFields["goal-weight-lower"].exists)
        XCTAssertTrue(app.textFields["goal-bodyFat-lower"].exists)
        XCTAssertEqual(app.textFields["goal-bodyFat-lower"].value as? String, "15")
    }
}
