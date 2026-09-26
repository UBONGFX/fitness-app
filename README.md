# FitnessApp

A SwiftUI fitness tracker for iOS 26. It supports reusable workout templates, free training sessions, set logging, body measurements, goals, HealthKit, and JSON export/import.

## Build and run

Install Xcode and XcodeGen, then run:

```sh
xcodegen generate
./Tools/run.sh sim
./Tools/test.sh
```

`./Tools/test.sh ui` runs UI tests. Set `FITNESS_SIM_ID` to select a simulator. For a signed device build, set `FITNESS_DEVELOPMENT_TEAM` in your shell or in the ignored `.private/signing.env`, then run `./Tools/run.sh phone`.

## Data and privacy

A new installation starts with a small generic exercise catalogue. Measurements, goals, sessions, and workout templates are stored on the device and are never bundled with the source. The app can export and import this data as JSON. Treat exported JSON files as private; `.gitignore` excludes files named `fitness-export-*.json`.

The repository excludes local signing settings, generated Xcode projects, build artifacts, simulator results, screenshots, and personal development notes. The Xcode project is generated from `project.yml`.

## License

MIT. See [LICENSE](LICENSE).
