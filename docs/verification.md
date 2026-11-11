# Verify record integrity and reminder recovery

The fast gate runs semantic lint, secret scanning, Swift 6 type checking, deterministic tests, and a simulator build.
The interface suite exercises saved records through native controls and audits accessibility.
Run the interface suite on iOS 26 and an available later runtime after changing app behavior.
When the Settings app lacks notification controls in Simulator, combine native denial and foreground journeys with hosted tests of the app's foreground handler using a controlled notification port.
The hosted tests also construct Apple's calendar trigger to check the absolute date across time zones.
The reminder outcome identifies the Actions and Repair lists.
[SwiftUI view identity](https://developer.apple.com/documentation/swiftui/view/id(_:)) resets state when its value changes.
Interface tests check notification guidance after launch, after saving, and after dismissal at the selected text size.

The transition tests cover all three-command sequences over seven commands for each work kind.
The 1,029 traces cover 3,087 transitions through production status, relocation, and renewal operations.
The model compares linked records and search membership with independently updated expected records.
The finite bound isn't a proof over arbitrary operation histories.
Controlled continuations test overlapping storage and notification operations without sleeps.
Real temporary files test atomic replacement, file size boundaries, corrupted snapshots, and rejected symbolic links.

Instrument the Swift package with Thread Sanitizer using `mise x -- just sanitize`.
The dedicated scratch directory keeps instrumented binaries separate from ordinary builds.
Instrumentation complements the explicit suspension tests.
A stale actor operation can violate ordering without a memory race.

Start a mutation campaign with `mise x -- just mutation-plan`.
The pinned [swift-mutation-testing tool](https://github.com/ericodx/swift-mutation-testing/tree/v1.7.1) mutates the core through all seven available operators.
The configuration limits concurrency to two, individual tests to 15 seconds, and builds to 120 seconds.
Each run rebuilds a clean sandbox and doesn't reuse mutation verdicts.
Run mutation analysis from a detached Git working tree of the committed source.
Keep the Git socket outside the copied checkout: `fsmonitor--daemon.ipc`.
Keep the package manifest, sources, tests, and app files used by source policy tests together.
Verify the configuration file matches the selected commit before trusting it: `mise.toml`.

The native report must contain no surviving or uncovered change, timeout, or integrity warning before accepting a campaign.
The tool's score includes timeouts as detected changes, so the score alone is insufficient.
A mutation that doesn't compile supplies no behavioral result.
Investigate surviving changes through the supported API and rerun the affected family after fixing the gap.
Don't introduce survivor baselines or operator exclusions to get a passing result.
Keep mutation analysis and instrumentation outside ordinary pull-request CI, and run the full campaign before release.
