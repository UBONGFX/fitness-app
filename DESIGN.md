---
name: Fitness App
description: A personal training logbook for workouts, exercise progression, and body goals.
colors:
  accent-dark: "color(display-p3 0.557 0.843 0.651)"
  accent-light: "color(display-p3 0.102 0.482 0.392)"
  canvas-dark: "#121416"
  surface-dark: "#202526"
  raised-dark: "#2B3032"
  canvas-light: "#F5F7F6"
  surface-light: "#FFFFFF"
  raised-light: "#E9EFEC"
typography:
  headline:
    fontFamily: "SF Pro"
    fontWeight: 700
  body:
    fontFamily: "SF Pro"
    fontWeight: 400
  data:
    fontFamily: "SF Pro"
    fontWeight: 600
rounded:
  card: "16px"
  control: "12px"
  badge: "8px"
spacing:
  tight: "8px"
  regular: "16px"
  loose: "20px"
  section: "32px"
components:
  record-card:
    backgroundColor: "{colors.surface-dark}"
    rounded: "{rounded.card}"
    padding: "20px"
  primary-button:
    backgroundColor: "{colors.accent-dark}"
---

# Design System: Fitness App

## Overview

**Creative North Star: "Athlete’s Logbook"**

Dated, scannable records make personal history the organizing idea. The interface is calm enough to read during a gym session and detailed enough to review goal and exercise progress later. Use real logged values and clear empty states; never fill a chart with sample results.

**Key Characteristics:** solid record surfaces, native iOS navigation, one restrained progress color, and numbers that are easy to compare.

## Colors

The adaptive accent is reserved for primary actions, selected navigation, and progress. Canvas, card, and raised neutrals adapt to light and dark appearance. Use native semantic text colors so labels maintain contrast in both modes.

**The One Accent Rule.** Do not color workout categories or routine icons with competing hues. Warning and destructive states may use system semantic colors when needed.

## Typography

Use the system SF Pro text styles and Dynamic Type. Large native navigation titles orient each main tab; semibold card titles identify records. Show weights, reps, dates, and percentages with monospaced digits for stable scanning. Keep secondary labels short and avoid all-caps prose; tracked uppercase is only for a small section label.

## Layout

Main screens use a single scroll column with 16-point side margins. Space items within a record by 8–16 points and separate major sections by 32 points. Keep the active exercise and its Add Set action together. Let charts collapse to an honest empty explanation when too few readings exist.

## Elevation & Depth

Solid tonal layers separate content from the canvas without shadows. Reserve system glass for native navigation, the floating workout plus button, and the timer accessory.

## Shapes

Cards use a 16-point radius, controls 12 points, and small labels 8 points. Group form rows into one rounded surface with subtle native separators.

## Components

Primary actions use native bordered prominent buttons in the adaptive accent. Secondary actions use bordered or plain buttons. Record cards use the shared `GlassCard` or `SolidCard` implementation in `Sources/DesignSystem/GlassCard.swift`; both render a solid surface. Forms use native controls and `glassRow()` for grouped rows. The Training plus button opens saved, new, and free workout actions.

## Do's and Don'ts

- **Do** place dates and units next to measured values.
- **Do** show goal, exercise, and training volume trends from stored records.
- **Don't** use a shifting gradient or colored glass behind workout content.
- **Don't** imply a period changed when it contains no new reading.
