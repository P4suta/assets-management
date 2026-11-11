# Verify record integrity and reminder recovery

The fast gate runs semantic lint, secret scanning, Swift 6 type checking, deterministic tests, and a simulator build.
The interface suite exercises saved records through native controls and audits accessibility.
Run the interface suite on iOS 26 and an available later runtime after changing app behavior.

The transition tests cover all three-command sequences over seven commands for each work kind.
The 1,029 traces cover 3,087 transitions through production status, relocation, and renewal operations.
The model compares linked records and search membership with independently updated expected records.
The finite bound isn't a proof over arbitrary operation histories.
Controlled continuations test storage and notification interleavings without sleeps.
Real temporary files test atomic replacement, file size boundaries, corrupted snapshots, and rejected symbolic links.

Run mise x -- just sanitize to instrument the Swift package with Thread Sanitizer.
The dedicated scratch directory keeps instrumented binaries separate from ordinary builds.
Instrumentation complements the explicit suspension tests because a logically stale actor operation need not contain a memory race.

Run mise x -- just mutation-plan before a mutation campaign.
The pinned [swift-mutation-testing tool](https://github.com/ericodx/swift-mutation-testing/tree/v1.7.1) mutates the core through all seven available operators.
The configuration limits concurrency to two, individual tests to 15 seconds, and builds to 120 seconds.
Run mutation analysis from a detached Git worktree of the committed source to keep Git's `fsmonitor` socket outside the copied checkout.
Keep the package manifest, sources, tests, and app files used by source policy tests together.
Trust the worktree's mise configuration only after comparing it with the selected commit.

The native report must contain no surviving or uncovered change, timeout, or integrity warning before accepting a campaign.
The tool's score includes timeouts as detected changes, so the score alone is insufficient.
A compiler-rejected mutation is unviable and supplies no behavioral result.
Investigate surviving changes through the supported API and rerun the affected family after fixing the gap.
Don't introduce survivor baselines or operator exclusions to get a passing result.
Keep mutation analysis and instrumentation outside ordinary pull-request CI, and run the full campaign before release.
