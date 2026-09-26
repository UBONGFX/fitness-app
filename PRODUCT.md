# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Individual strength trainees who want to choose a workout for each session, log sets while training, and review progress between sessions. The primary user is confirmed; the session workflow is supported by the current app.

## Product Purpose

Help an individual lifter train flexibly, track set-by-set performance, and understand progress toward personal goals over time. The app supports reusable workouts without a fixed weekly schedule, saved or free sessions, and set logging.

## Positioning

Workouts are reusable but not tied to weekdays. The user chooses what to train each session and can review how individual exercises and personal goals change over time.

## Operating Context

The interface is currently German-only. The app is used to prepare or start a workout, record exercises and sets during a session, and review training or body progress later. Body weight and body-fat data can be read from HealthKit when access is granted.

## Capabilities and Constraints

- Native SwiftUI app targeting iOS 26, built with Swift 6 and SwiftData.
- Supports reusable workout templates, free sessions, exercise and set logging, exercise history, body measurements, goal tracking, and trend summaries.
- Data is stored on-device. Users control JSON export and import; exported files contain private fitness data.
- HealthKit access is optional and permission-based. CloudKit sync is disabled; do not imply that data syncs between devices.
- Existing on-device records must remain usable when workout screens or models change.
- The main product priority is flexible workouts, exercise progression, and clear insight into progress toward personal goals.

## Evidence on Hand

The repository contains the working iOS app, synthetic unit tests, and workout-flow UI tests. It does not contain external customer, clinical, or performance evidence; do not invent endorsements or health claims.

## Product Principles

- Let the user decide what to train each session instead of requiring a weekly schedule.
- Make recording and reviewing performed sets central to the training workflow.
- Show how individual exercises and personal goals progress over time.
- Keep training and body progress in one personal fitness tool.
- Keep fitness data under the user's control and describe storage and sync truthfully.
