---
date: 2026-11-11
status: proposed
---

# Native records with atomic local storage

## Context

The Figma design targets iPhone on iOS 26 or later with on-device records.
The owner selected Apple's system design, system indigo, and two tabs without cash flow.

## Decision

Use native SwiftUI controls with an observable store and a pure Swift domain package.
Store a validated JSON snapshot with a format number and copied attachments in `Application Support`.
Serialize writes through an actor and publish changes only after an atomic save succeeds.
[Apple's adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) supports native controls.
[Atomic writing](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) replaces the original file after a complete write.

## Alternatives

SwiftData would provide queries and relationships but adds migration behavior for a small local dataset.
A server database would add accounts and networking outside the approved scope.

## Consequences

Snapshots make domain rules and failed writes testable without a UI or database runtime.
Every edit rewrites the snapshot, so reconsider storage when measured record volume makes saves slow.
Contract renewal drafts keep the signed contract unchanged until explicit confirmation.

## Confirmation

Run domain and storage tests for validation, referential integrity, interrupted writes, and relaunch.
Run native interface journeys and accessibility checks using the approved Figma screens.
The record remains proposed for owner review.
