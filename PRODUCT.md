# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Individual strength trainees who want to choose a workout for each session, log sets while training, and review progress between sessions. The primary user is confirmed; the session workflow is supported by the current app.

## Product Purpose

Help an individual lifter train flexibly and track set-by-set progress over time. The app supports creating reusable workouts without assigning them to a fixed weekly schedule, starting a saved workout or a free session, and recording performed sets.

## Positioning

Workouts are reusable but not tied to weekdays. The user chooses what to train each session and can compare logged performance over time. Body measurements and goals support progress tracking alongside training.

## Operating Context

The interface is currently German-only. The app is used to prepare or start a workout, record exercises and sets during a session, and review training or body progress later. Body weight and body-fat data can be read from HealthKit when access is granted.

## Capabilities and Constraints

- Native SwiftUI app targeting iOS 26, built with Swift 6 and SwiftData.
- Supports reusable workout templates, free sessions, exercise and set logging, progression history, body measurements, and goals.
- Data is stored on-device. Users control JSON export and import; exported files contain private fitness data.
- HealthKit access is optional and permission-based. CloudKit sync is disabled; do not imply that data syncs between devices.
- Existing on-device records must remain usable when workout screens or models change.
- The main product priority is flexible workouts and set progress. Body tracking is a supporting feature.

## Evidence on Hand

The repository contains the working iOS app, synthetic unit tests, and workout-flow UI tests. It does not contain external customer, clinical, or performance evidence; do not invent endorsements or health claims.

## Product Principles

- Let the user decide what to train each session instead of requiring a weekly schedule.
- Make recording and reviewing performed sets central to the training workflow.
- Keep training and body progress in one personal fitness tool.
- Keep fitness data under the user's control and describe storage and sync truthfully.
