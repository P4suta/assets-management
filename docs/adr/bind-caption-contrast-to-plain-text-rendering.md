---
date: 2026-11-16
status: proposed
---

# Bind caption contrast to plain text rendering

## Context

Japanese strokes can contain blended pixels without an opaque interior.
A screenshot can't establish whether intermediate colors came from smoothing or authored text.
The [Web Content Accessibility Guidelines explanation](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) distinguishes authored colors from smoothed edges.

## Decision

Render identified record captions through one component accepting a String, a typed role, and an optional monochrome symbol.
Use Apple's [literal Text initializer](https://developer.apple.com/documentation/swiftui/text/init(verbatim:)) and one foreground style for the entire caption.
Share the role inventory with interface tests.
For identified captions, compare the dominant ink with every measured background.
Exclude emoji sequences from the single-paint measurement.
Other images use the lowest ratio among sampled paints.

## Alternatives

Sampling every blended edge reports insufficient contrast for valid native text.
Ignoring connected secondary paints misses weak text beside stronger text.
Increasing font weight changes the product to accommodate the measurement.

## Consequences

The single-paint measurement is conditional on the shared rendering contract.
It doesn't establish arbitrary image contrast.
Reconsider the contract before adding attributed text or applying styles inside the caption.

## Confirmation

Require mixed-color rejecting fixtures, native caption captures, and selected-row journeys in both appearances.
Keep a native deadline capture whose smoothed edges exercise the distinction.
