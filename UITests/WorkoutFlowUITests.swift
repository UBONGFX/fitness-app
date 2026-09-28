import XCTest

final class WorkoutFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-startTab", "training", "-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testFinishedExerciseIsAvailableInProgressIndex() {
        let app = launch()
        app.buttons["workoutPlus"].tap()
        app.buttons["Freies Training starten"].tap()
        XCTAssertTrue(app.buttons["addSessionExercise"].waitForExistence(timeout: 10))
        app.buttons["addSessionExercise"].tap()
        app.buttons["pickSession-Bankdrücken"].tap()
        app.buttons["addSet-Bankdrücken"].tap()
        app.buttons["saveSet"].tap()
        app.buttons["finishSession"].tap()
        XCTAssertTrue(app.buttons["confirmFinishSession"].waitForExistence(timeout: 5))
        app.buttons["Weiter trainieren"].tap()
        XCTAssertFalse(app.buttons["confirmFinishSession"].exists)
        app.buttons["finishSession"].tap()
        app.buttons["confirmFinishSession"].tap()

        let index = app.buttons["openExerciseProgress"]
        XCTAssertTrue(index.waitForExistence(timeout: 5))
        index.tap()
        XCTAssertTrue(app.navigationBars["Übungsfortschritt"].waitForExistence(timeout: 5))

        let exercise = app.buttons["exerciseProgress-Bankdrücken"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        exercise.tap()
        XCTAssertTrue(app.navigationBars["Bankdrücken"].waitForExistence(timeout: 5))
    }
}
