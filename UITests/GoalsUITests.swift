import XCTest

final class GoalsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testCreatesPrimaryObservation() {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "body", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.buttons["openGoals"].waitForExistence(timeout: 10))
        app.buttons["openGoals"].tap()
        app.buttons["addGoal"].tap()
        app.buttons["FFMI"].tap()
        XCTAssertTrue(app.buttons["editGoal-ffmi"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Körperfett"].exists)
        capture("Goal editor with primary FFMI observation")

        app.buttons["addGoal"].tap()
        app.buttons["Gewicht"].tap()
        app.segmentedControls["goal-weight-priority"].buttons["Primär"].tap()
        app.buttons["editGoal-weight"].tap()
        capture("Goal editor with spaced primary goals")
        app.buttons["saveGoals"].tap()

        XCTAssertTrue(app.buttons["editGoals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["FFMI"].exists)
        capture("Goal overview without measurements")
    }

    @MainActor
    func testGoalsCanBeObservedPrioritizedAndRemovedIndependently() {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "body", "-uiTesting"]
        app.launch()

        let openGoals = app.buttons["openGoals"]
        XCTAssertTrue(openGoals.waitForExistence(timeout: 10))
        openGoals.tap()

        app.buttons["addGoal"].tap()
        app.buttons["FFMI"].tap()
        XCTAssertTrue(app.buttons["editGoal-ffmi"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Körperfett"].exists)
        app.buttons["saveGoals"].tap()

        let editGoals = app.buttons["editGoals"]
        XCTAssertTrue(editGoals.waitForExistence(timeout: 5))
        editGoals.tap()
        XCTAssertTrue(app.buttons["editGoal-ffmi"].waitForExistence(timeout: 5))

        app.buttons["addGoal"].tap()
        app.buttons["Gewicht"].tap()
        app.segmentedControls["goal-weight-priority"].buttons["Primär"].tap()
        capture("Goal editor with two selected goals")
        let weightValue = app.textFields["goal-weight-lower"]
        XCTAssertTrue(weightValue.waitForExistence(timeout: 5))
        weightValue.tap()
        weightValue.typeText("80")
        app.buttons["saveGoals"].tap()

        editGoals.tap()
        XCTAssertTrue(app.buttons["editGoal-ffmi"].exists)
        app.buttons["editGoal-weight"].tap()
        XCTAssertEqual(app.textFields["goal-weight-lower"].value as? String, "80")
        app.buttons["removeGoal-weight"].tap()
        app.buttons["saveGoals"].tap()

        editGoals.tap()
        XCTAssertTrue(app.buttons["editGoal-ffmi"].exists)
        XCTAssertFalse(app.buttons["editGoal-weight"].exists)
        XCTAssertFalse(app.staticTexts["Körperfett"].exists)
    }

    @MainActor
    func testAllMeasurementsLinkClearsBottomNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "body", "-uiTesting"]
        app.launch()

        app.buttons["Erste Messung erfassen"].tap()
        let weight = app.textFields["metric-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("80")
        app.buttons["Sichern"].tap()

        let allMeasurements = app.buttons["openMeasurements"]
        XCTAssertTrue(allMeasurements.waitForExistence(timeout: 5))
        let overview = app.scrollViews.firstMatch
        let navigation = app.buttons["Körper"]
        for _ in 0..<5 where allMeasurements.frame.maxY >= navigation.frame.minY {
            overview.swipeUp()
        }
        XCTAssertTrue(allMeasurements.isHittable)
        XCTAssertLessThan(allMeasurements.frame.maxY, navigation.frame.minY)
        capture("All measurements above bottom navigation")

        allMeasurements.tap()
        XCTAssertTrue(app.segmentedControls["bodySection"].buttons["Messungen"].isSelected)
    }

    @MainActor
    func testSettingsGeneralGroupStartsWithoutAnExtraSeparator() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        let settings = app.buttons["openSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.buttons["openAppearance"].waitForExistence(timeout: 5))
        capture("Settings general group")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
