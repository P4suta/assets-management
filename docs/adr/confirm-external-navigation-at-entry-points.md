---
date: 2026-11-13
status: proposed
---

# Confirm external navigation at entry points

## Context

The requested interaction policy confirms destinations before leaving the app.
Apple recommends [using alerts sparingly](https://developer.apple.com/design/human-interface-guidelines/alerts), so confirmation applies to external navigation rather than record navigation.

## Decision

Route hyperlinks through SwiftUI's [open URL environment action](https://developer.apple.com/documentation/swiftui/openurlaction).
Show the destination with Open and Cancel actions before forwarding it to the system.
Route Settings and document-preview links through the same boundary.
Use the [system telephone confirmation](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html) for calls.
Confirm the support site's email handoff with the browser's [native confirmation dialog](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm-dev).

## Alternatives

Default links require fewer interruptions but omit the requested confirmation for websites and email.
Separate handlers at every link duplicate presentation and cancellation rules.

## Consequences

Each presentation owns its pending destination, and cancellation keeps the presenting screen open.
Nested presentations inherit the original system action to avoid confirming twice.
The requested confirmation adds an interruption before external navigation.
Reconsider when the app gains internal URL routes or an embedded browser.

## Confirmation

Check cancellation, exact destination handoff, repeated requests, and unavailable handlers.
Exercise links from sheets, notification guidance, contacts, and document previews.
Reject direct app URL calls that bypass the environment action.
