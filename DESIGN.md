---
name: Fitness App
description: A measured training field guide for flexible workouts and personal progress.
colors:
  clay-light: "color(display-p3 0.785 0.315 0.185)"
  clay-dark: "color(display-p3 0.975 0.575 0.475)"
  paper-light: "#F3F2EB"
  paper-dark: "#161B18"
  surface-light: "#FBFAF4"
  surface-dark: "#222824"
  raised-light: "#E3E4DB"
  raised-dark: "#323833"
  rule-light: "rgba(38, 54, 46, 0.32)"
  rule-dark: "rgba(204, 212, 196, 0.24)"
typography:
  page-title:
    fontFamily: "iOS system serif"
    fontWeight: 700
    letterSpacing: "-0.5pt"
  section-title:
    fontFamily: "iOS system serif"
    fontWeight: 600
  body:
    fontFamily: "iOS system"
  measured-data:
    fontFamily: "iOS system, monospaced digits"
rounded:
  form-row: "12pt"
  badge: "8pt"
spacing:
  tight: "8pt"
  regular: "16pt"
  loose: "20pt"
  section: "32pt"
components:
  ruled-record:
    padding: "16pt 0"
  grouped-form-row:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.form-row}"
  grouped-form-row-dark:
    backgroundColor: "{colors.surface-dark}"
    rounded: "{rounded.form-row}"
  neutral-badge:
    backgroundColor: "{colors.raised-light}"
    rounded: "{rounded.badge}"
    padding: "4pt 10pt"
  neutral-badge-dark:
    backgroundColor: "{colors.raised-dark}"
    rounded: "{rounded.badge}"
    padding: "4pt 10pt"
---

# Design System: Fitness App

## Overview

**Creative North Star: “Training Field Guide”**

Personal training progress reads as an open, measured page. Warm matte paper and deep olive ink support dated evidence, while thin rules separate sections across the available width. Strong editorial headings orient the reader; native system text keeps sets, forms, and measurements legible during a workout.

The interface follows real stored records and names empty states plainly. The flexible workout flow, native iOS navigation, Dynamic Type, and optional HealthKit remain part of the product. The approved visual direction is a guide to material and rhythm, not a source of decorative slogans or sample data.

**Key Characteristics:** full-width ruled records; warm adaptive neutrals; rare clay accent for actions and meaningful progress; native controls and tab chrome; monospaced measured digits.

## Colors

### Primary

- **Clay orange:** `clay-light` and `clay-dark` are the asset-catalog accent for prominent actions, selected native controls, and favorable measured change. The two Display P3 values adapt to appearance.

### Neutral

- **Matte paper:** `paper-light` and `paper-dark` fill the screen through `AppBackground`.
- **Inset paper:** `surface-light` and `surface-dark` back grouped form rows and occasional inset notices.
- **Raised neutral:** `raised-light` and `raised-dark` back small badges.
- **Fine rule:** `rule-light` and `rule-dark` separate open records. Text uses native primary and secondary semantic colors so contrast follows the current appearance.

**The Measured Accent Rule.** Use clay for actions and actual progress. Keep section rules, category badges, and supporting labels neutral. System semantic warning and destructive colors remain appropriate for those states.

## Typography

**Display font:** iOS system serif, with Dynamic Type text styles.
**Body font:** iOS system sans, with native text styles.

### Hierarchy

- **Page title:** bold serif `largeTitle`, tracked slightly tighter. Used for main screen headings such as Fortschritt, Training, and Körper.
- **Section title:** semibold serif `title3`, with `title2` on prominent goal and detail records.
- **Body and controls:** native body, subheadline, headline, and footnote styles according to reading priority.
- **Measured data:** native styles with monospaced digits for weights, repetitions, counts, dates, and comparisons.
- **Supporting label:** native caption styles in secondary semantic color.

**The Editorial Heading Rule.** Serif type orients a page or record; dense set data and form controls stay in system sans.

## Layout

Main reading screens use one scroll column with regular side inset and full-width content inside it. Overview, Training, and Body cap their reading columns at 640 points on wide displays. `GlassCard` and `SolidCard` are historical code names for open sections: each spans the column, adds vertical breathing room, and draws a one-point rule at its top. Content within a section usually follows the regular spacing step; small comparisons use the tight step.

The overview starts with a dated heading and native period picker, then presents goal, exercise, and training-volume evidence in ruled sections. Larger Dynamic Type can stack metric comparisons vertically. Training puts this week's volume before the workout library so progress is visible immediately. Training, live sets, history, Body, and data tools use the same open-section grammar where they present records. Native `List` and `Form` screens keep grouped rows for editing and settings. The bottom navigation reserves space for the rest timer when shown.

## Elevation & Depth

The reading canvas and ruled records are flat, without custom shadows. Fine rules and subtle tonal differences establish hierarchy. Native glass remains on system navigation, the Training add action, and the rest timer accessory; it follows iOS behavior rather than becoming a background material for every record.

## Shapes

Open records have square edges and no enclosing card. Grouped form rows retain gently rounded outer corners; only the first and last rows round in a multirow group. Small neutral badges use a tighter radius. Native buttons, segmented pickers, tabs, sheets, and other controls keep their system shapes.

## Components

### Ruled records

`GlassCard` and `SolidCard` provide an open, full-width section with regular vertical padding and a fine top rule. A semantic tint may replace a `GlassCard` rule for a specific status. They do not paint a card surface.

### Headings

`FieldGuidePageTitle` supplies the bold serif page heading and accessibility header trait. `SectionHeader` pairs a semibold serif section title with an optional quiet footnote subtitle.

### Actions and navigation

Primary actions use native bordered prominent controls with the adaptive clay accent. Secondary actions use native bordered or plain styles. The bottom navigation uses a shared Liquid Glass capsule for Übersicht, Training, and Körper. On Training, a separate circular glass add button shares its row. The rest timer sits above the navigation in a glass capsule. Ending a session shows an inline confirmation area above the timer with options to continue or finish.

### Badges and grouped rows

`GlassBadge` uses a compact raised-neutral fill for categories and counts. `glassRow()` places native list rows on an inset paper surface with outer corner rounding and separators between adjacent rows. Forms use `glassFormBackground()` on the matte canvas.

## Do's and Don'ts

### Do:

- **Do** place units and dates with measured values and use monospaced digits where comparison matters.
- **Do** show goal, exercise, and volume changes from stored records and explain missing readings honestly.
- **Do** keep native controls and Dynamic Type behavior in form and training flows.

### Don't:

- **Don't** restore repeated enclosed cards on reading screens; use the ruled section treatment.
- **Don't** use clay as category decoration or imply a trend changed without a reading in the period.
- **Don't** add illustrative values, slogans, or anatomy art from the approved comp as product data.
