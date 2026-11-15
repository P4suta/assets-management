---
date: 2026-11-15
status: proposed
---

# Validate compatible rendering with native host recognition

## Context

The visionOS 27.2 Simulator fails to load its text-recognition models through an encoded runtime path.
The captured date and blank image pass [accurate recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images) on macOS.

## Decision

Keep rendering, geometry, and pixel measurements on the target platform.
An explicit capture scheme preserves each recognition input and its typed expectation as test attachments.
A macOS test target recognizes the exported images and checks the complete expected inventory.
The compatibility command succeeds only after both phases pass.

## Alternatives

Recognition inside every target keeps the existing single-phase check but fails in the affected runtime.
Fast recognition misreads the known date and doesn't preserve the required Japanese coverage.
Visual inspection supplies no repeatable rejection of truncated captions.

## Consequences

The test target contains no shipping code or network service.
Empty, missing, duplicate, and mismatched captures fail validation.
Reconsider the split when the target runtime passes the exact-date, blank-image, and truncation controls with accurate recognition.

## Confirmation

Require all target-hosted tests and every expected recognition input.
Check exact dates, complete Japanese captions, blank images, and native ellipsis rejection.
Confirm that deleting an input or replacing its expected text fails the final gate.
