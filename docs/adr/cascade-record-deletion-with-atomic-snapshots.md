---
date: 2026-11-19
status: proposed
---

# Cascade record deletion with atomic snapshots

## Context

Building registration creates a room, and property and work records can have attachments and pending notifications.
Deleting these records requires confirmation of the affected records and preservation of shared contacts.

## Decision

Derive confirmation and deletion from one typed plan and ask for confirmation again when the scope changes.
Commit the validated record snapshot with [atomic replacement](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic).
After the commit, remove files with no reference in the persisted snapshot and reconcile [pending notifications](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:)).

## Alternatives

Requiring individual removal of related records gives precise control and requires deleting the first room to undo a mistaken registration.
A cleanup journal tracks individual file deletions and adds persistent state to recover alongside the snapshot.

## Consequences

The app can resume file cleanup after an interruption using the current snapshot format.
An unreadable or absent snapshot prevents attachment cleanup.
Reconsider directory scanning if measured cleanup latency slows launch or deletion.

## Confirmation

Test each deletion target, stale confirmation, write failure, partial file cleanup, and relaunch.
Check native confirmation, navigation, and removal of pending notifications.
