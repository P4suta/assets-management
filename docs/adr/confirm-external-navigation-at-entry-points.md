---
date: 2026-11-13
status: proposed
---

# Confirm external navigation at entry points

## Context

Confirm destinations before leaving the app.
Apple recommends [sparse alerts](https://developer.apple.com/design/human-interface-guidelines/alerts).

## Decision

Route hyperlinks through SwiftUI's [open URL environment action](https://developer.apple.com/documentation/swiftui/openurlaction).
Show the destination with Open and Cancel before forwarding it.
Route Settings and document-preview links through the same boundary.
Use the documented [iOS telephone confirmation](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html) on iPhone and iPad.
Compatible Mac and Apple Vision Pro apps confirm calls before the system handoff.
Normalize telephone formatting and [encode mailbox characters](https://www.rfc-editor.org/rfc/rfc6068.html#section-2).
Keep unrecognized contact text selectable without an external action.
Confirm the support site's email handoff with the browser's [native confirmation dialog](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm-dev).

## Alternatives

Default links omit confirmation for websites and email.
Separate handlers duplicate presentation and cancellation rules.

## Consequences

Each presentation owns its destination.
Cancellation keeps the screen open.
Nested presentations inherit the original system action to avoid confirming twice.
Confirmation adds an interruption.
Reconsider with internal routes or an embedded browser.

## Confirmation

Check cancellation, exact handoff, repeated requests, and unavailable handlers.
Exercise links from sheets, notification guidance, contacts, and document previews.
Reject direct app URL calls that bypass the environment action.
