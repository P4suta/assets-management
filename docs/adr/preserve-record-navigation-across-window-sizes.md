---
date: 2026-11-13
status: proposed
---

# Preserve record navigation across window sizes

## Context

iPad and iPhone Duo windows can resize during editing.
The [existing decision](native-records-with-atomic-local-storage.md) retains two tabs and on-device records.

## Decision

Declare iPhone and iPad support with four iPad orientations.
Keep each tab's selection in SwiftUI state and use [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview) for the list and detail.
Use [sidebar-adaptable tabs](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) and system sheets without branching on device names or orientation.
[Apple's Duo guidance](https://developer.apple.com/iphone-duo/prepare/) requires layouts to react to available space and asymmetric system bars.

## Alternatives

A single navigation stack would keep the phone interaction but leave wide windows without a visible list beside the selected record.
Separate layouts for named devices would duplicate navigation state and lose edits when the active layout changes.

## Consequences

The system controls column collapse, bar placement, and sheet sizing.
Changing the selected record resets its detail navigation, while resizing preserves the selected record and draft.
Reconsider the structure when a task needs record comparison.

## Confirmation

Verify registration, repair, renewal, attachments, cancellation, and relaunch on supported simulators.
Check rotation and resizing during an unsaved edit, both appearances, the largest text size, and Increase Contrast.
Keep physical-device acceptance distinct from simulator results before submitting for review.
