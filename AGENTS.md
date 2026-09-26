# Repository Guidelines

## Project Structure & Module Organization

`Sources/App` contains the app entry point, configuration, and root view. Put reusable UI in `Sources/DesignSystem`, screen code in `Sources/Features/<Feature>`, data types in `Sources/Models`, and app logic or integrations in `Sources/Services`. Images and colors live in `Sources/Resources/Assets.xcassets`. Unit tests are in `Tests` and UI tests in `UITests`. `project.yml` defines the generated Xcode project; build directories and screenshots are local artifacts.

## Build, Test, and Development Commands

- `xcodegen generate` regenerates `FitnessApp.xcodeproj` after changes to `project.yml` (requires XcodeGen).
- `./Tools/run.sh` builds and launches on an available iPhone simulator; `./Tools/run.sh phone` uses a connected iPhone with a locally configured signing team.
- `./Tools/test.sh` runs unit tests. `./Tools/test.sh ui` runs UI tests except screenshot capture, `./Tools/test.sh all` runs unit and UI tests, and `./Tools/test.sh shots` runs screenshot capture.
- `./Tools/test.sh WorkoutLibraryTests` runs one unit suite; a UI suite such as `WorkoutFlowUITests` works the same way. Set `FITNESS_SIM_ID` to select a simulator.

Use Xcode with an iOS 26 simulator and the `FitnessApp` scheme. The scripts write build output and test logs under `build2` or `build3`.

## Coding Style & Naming Conventions

Use Swift 6 and four-space indentation, following nearby files. Name types and Swift files in `UpperCamelCase`, properties and functions in `lowerCamelCase`, and feature views with a `View` suffix. Keep domain calculations in models or services and keep SwiftUI views focused on presentation. No formatter or linter configuration is present; match existing formatting and compile with the project settings, including main-actor isolation.

## Testing Guidelines

Unit tests use Swift Testing (`@Test`, `#expect`) and files named `<Subject>Tests.swift`. UI tests use XCTest and files named `<Feature>UITests.swift`. Add focused unit coverage for model or service behavior and UI coverage for changed interactions. Run the relevant suite before a pull request; run `./Tools/test.sh all` for broader changes. No coverage threshold is configured.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects that describe one focused change, such as `Add session history sorting`. Pull requests should explain the user-visible behavior, list tests run, and link any relevant issue. Include screenshots for visual changes, and mention changes to HealthKit permissions, persistence, or `project.yml` explicitly. Never commit personal measurements, export files, signing data, or local development notes.
