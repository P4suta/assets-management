---
date: 2026-11-12
status: proposed
---

# Reconcile reminders from committed records

## Context

An older scheduling call can recreate a reminder after a newer edit completes the work.
Permission can change in Settings while the app is away.

## Decision

Derive requests from committed records through a pure calendar policy.
Serialize notification effects and discard superseded plans after each suspension.
Link [tasks through their results](https://docs.swift.org/latest/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency) instead of resuming continuations manually.
Reconcile on foreground entry and prompt only after an explicit reminder edit.
[Apple's authorization guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) requires fresh settings and recommends contextual prompts.
[Request identifiers](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier) support replacement and cancellation.
Verify [pending requests](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getpendingnotificationrequests(completionhandler:)) after registration and offer a retry for missing future requests.

## Alternatives

Independent calls leave ordering across suspension points uncontrolled.
A persisted queue survives interruptions but duplicates records and requires recovery metadata.

## Consequences

Use the displayed minute and a 09:00 local deadline reminder.
Encode absolute triggers in UTC to disambiguate repeated daylight saving times.
Interrupted registration recovers on foreground entry.
Reconsider a persisted queue if recovery must work while the app remains closed.

## Confirmation

Test calendar boundaries, authorization, registration failures, and superseding snapshots.
Verify native permission denial preserves saved schedules.
The record remains proposed for owner review.
