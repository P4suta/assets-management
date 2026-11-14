---
date: 2026-11-14
status: proposed
---

# Schedule contract notices from recorded deadlines

## Context

People need preparation time for renewal or termination.
[The ministry's fixed-term lease guidance](https://www.mlit.go.jp/jutakukentiku/house/jutakukentiku_house_tk3_000060.html) describes conditional notice periods.
One universal six-month rule can't represent rental agreements.

## Decision

Record a deadline or a user-selected interval before contract expiry, with an optional advance reminder.
Treat presets as date calculations rather than legal determinations.
Use Japan time for [picker dates](https://developer.apple.com/documentation/swiftui/environmentvalues/timezone), [display formatting](https://developer.apple.com/documentation/foundation/date/formatstyle), calculations, and reminders.
Use typed work and contract targets in the existing serialized notification coordinator.
Keep notification content generic and open the related record after selection, following [Apple's notification guidance](https://developer.apple.com/design/human-interface-guidelines/notifications).
Defer navigation while an editor is open.
Track the sheet's persistent destination and dismissal rather than the editor content's appearance callbacks.

## Alternatives

Automatic legal deadlines require agreement details and interpretations the app doesn't hold.
Manual calendar entries separate reminders from their contracts.

## Consequences

People select dates from their agreements.
Local delivery depends on notification permission and system scheduling.
Saved deadlines remain visible when scheduling fails.
Reconsider external delivery when the product gains an authorized synchronization service.

## Confirmation

Check migration, month ends, leap years, travel, changed contracts, permission, retries, target collisions, and deferred navigation.
