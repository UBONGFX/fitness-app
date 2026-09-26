import XCTest

final class WorkoutFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "training", "-uiTesting"]
        app.launch()
        return app
    }

    func testCreatesAReusableWorkout() {
        let app = launch()
        XCTAssertTrue(app.buttons["workoutPlus"].waitForExistence(timeout: 10))
        app.buttons["workoutPlus"].tap()
        app.buttons["Neues Workout erstellen"].tap()
        let name = app.textFields["workoutName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Oberkörper")
        app.buttons["saveWorkout"].tap()
        XCTAssertTrue(app.buttons["addExercise"].waitForExistence(timeout: 5))
    }

    func testStartsAFreeSessionAndAddsAnExercise() {
        let app = launch()
        XCTAssertTrue(app.buttons["workoutPlus"].waitForExistence(timeout: 10))
        app.buttons["workoutPlus"].tap()
        app.buttons["Freies Training starten"].tap()
        XCTAssertTrue(app.buttons["addSessionExercise"].waitForExistence(timeout: 5))
        app.buttons["addSessionExercise"].tap()
        app.buttons["pickSession-Bankdrücken"].tap()
        XCTAssertTrue(app.buttons["addSet-Bankdrücken"].waitForExistence(timeout: 5))
    }
}
