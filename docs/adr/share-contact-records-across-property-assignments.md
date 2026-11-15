---
date: 2026-11-14
status: proposed
---

# Share contact records across property assignments

## Context

The requested directory includes emergency, maintenance, management, insurance, and fire-safety contacts.
Resident and agency references already share local contact identifiers.

## Decision

Add Contacts beside Actions and Properties, following [Apple's tab guidance](https://developer.apple.com/design/human-interface-guidelines/tab-bars).
Keep one contact record with a category, independent emergency priority, and explicit building links.
Preserve resident and agency assignments and derive their property associations.
Use native lists, forms, search, and confirmed telephone or email handoffs.
Migrate snapshots from format 1 to format 2 and write the updated format atomically.

## Alternatives

Separate directories per building duplicate shared companies.
Earlier builds can overwrite unrecognized fields in format 1.

## Consequences

Updating a contact updates every assignment.
Deletion clears references while retaining property and work records.
Earlier builds reject updated snapshots.
Reconsider the category model when contacts need more than one service classification.

## Confirmation

Check legacy decoding, round trips, invalid links, deletion, emergency ordering, search, shared property links, and adaptive journeys.
