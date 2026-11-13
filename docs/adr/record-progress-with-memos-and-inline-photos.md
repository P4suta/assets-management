---
date: 2026-11-13
status: proposed
---

# Record progress with memos and inline photos

## Context

The requested experience shows unfinished and completed work together and records short memos and photos.
Separate completed lists and contact workflows add unwanted navigation.

## Decision

Show active and completed work in one searchable list.
Use one editing entry per detail screen and display memos and inline photos.
Host photo presentations on each record list because [Group modifiers reach every member](https://developer.apple.com/documentation/swiftui/group).
Keep property editing within the Properties tab.
Use history entries for memos and preserve stored record fields and attachments.
Normalize imported photos to bounded image data and render thumbnails through [Image I/O](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)).
Use system content surfaces beneath navigation, following [Apple's materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials).

## Alternatives

The separate completed list limits the overview of work.
Keeping every shortcut preserves access paths but retains the unwanted complexity.
Original-resolution image decoding increases memory use during scrolling and import.

## Consequences

Preserve the storage format.
Existing document attachments remain viewable, and new attachment controls accept photos.
Photo normalization trades original resolution for bounded storage and decoding.
Reconsider document import or original-resolution storage when users need to keep source files.

## Confirmation

Check progress states, search, rotation, memo persistence, inline images, image failures, and property navigation.
