---
date: 2026-11-13
status: proposed
---

# Confirm external navigation at entry points

## Context

The requested interaction policy confirms destinations before leaving the app.
Apple recommends [sparse alerts](https://developer.apple.com/design/human-interface-guidelines/alerts).
Confirm external navigation.

## Decision

Route hyperlinks through SwiftUI's [open URL environment action](https://developer.apple.com/documentation/swiftui/openurlaction).
Show the destination with Open and Cancel actions before forwarding it to the system.
Route Settings and document-preview links through the same boundary.
Use the [system telephone confirmation](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html) for calls.
Normalize recognized telephone formatting and [encode mailbox characters](https://www.rfc-editor.org/rfc/rfc6068.html#section-2) before handing off a destination.
Keep unrecognized contact text readable and selectable without creating an external action.
Confirm the support site's email handoff with the browser's [native confirmation dialog](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm-dev).

## Alternatives

Default links require fewer interruptions but omit the requested confirmation for websites and email.
Separate handlers at every link duplicate presentation and cancellation rules.

## Consequences

Each presentation owns its destination.
Cancellation keeps the screen open.
Nested presentations inherit the original system action to avoid confirming twice.
The requested confirmation adds an interruption before external navigation.
Reconsider with internal routes or an embedded browser.

## Confirmation

Check cancellation, exact handoff, repeated requests, and unavailable handlers.
Exercise links from sheets, notification guidance, contacts, and document previews.
Reject direct app URL calls that bypass the environment action.
