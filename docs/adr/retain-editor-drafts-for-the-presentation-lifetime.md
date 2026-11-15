---
date: 2026-11-13
status: proposed
---

# Keep editor drafts for the presentation lifetime

## Context

An unsaved repair title reverted when iPhone Duo moved the same scene between displays.
Editors store inputs inside the presented view.
[SwiftUI state](https://developer.apple.com/documentation/swiftui/state) belongs to its hierarchy, while [observable models](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) supply bindings across view replacements.

## Decision

Give each presentation a unique identity and a typed observable session retained by its destination.
Keep drafts, baseline values, validation, save progress, and errors in the session.
Prepare records once and persist through explicit saving.
Release the session after saving or discarding.

## Alternatives

View-local state requires presentations to preserve the editor hierarchy.
Persisting unfinished inputs adds a storage contract beyond in-session continuity.

## Consequences

Editors bind to session values without sharing drafts between presentations.
Reconsider persistence when the app needs process restoration.

## Confirmation

Replace hosted editor views and verify retained inputs and unchanged stored records.
Check discard, save failure, retry, and fresh presentations.
Confirm Duo display transitions and existing simulator journeys.
