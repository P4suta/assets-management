# Verify record integrity and reminder recovery

The fast gate runs semantic lint, secret scanning, Swift 6 type checking, deterministic tests, and a simulator build.
Xcode builds turn off compilation caching to reduce temporary disk use during checks.
The interface suite exercises saved records through native controls and audits accessibility.
Run the rotation checks on iPad and iPhone Duo simulators with `mise x -- just adaptive-ui-test`.
Run window resizing with the selected record and an open editor, and verify the same title, draft value, and reachable save action afterward.
Keep physical-device acceptance and the App Review recording separate from simulator results.
Selected-row tests audit foreground contrast within the visible selection in both appearances.
Selected rows use the primary system label for text and status symbols.
The style adjusts for its [highlighted background](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundprominence).
The iPadOS 27.2 audit reports insufficient contrast for a selected deadline whose captured black text has a measured ratio of 12.298:1.
The test also measures the current status and deadline screenshots using the sRGB luminance and contrast formula from the [Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/TR/WCAG22/#dfn-relative-luminance).
The measurement covers captions drawn with a single foreground color on an opaque background.
Status symbols use [monochrome rendering](https://developer.apple.com/design/human-interface-guidelines/sf-symbols#Rendering-modes).
The test groups background colors within one 8-bit step per channel and uses the lowest contrast for the group.
Unsupported or ambiguous images fail verification.
The audit filter requires the affected OS, issue type, label, element type, selection, matching frame, and a fresh measured ratio of at least 4.5:1.
Unknown reports remain failures.
[Apple's issue-handler example](https://developer.apple.com/videos/play/wwdc2023/10035/?time=597) supports filtering a specific contrast false positive after checking the label.
The screen tour also audits contrast with Increase Contrast enabled.
A [VoiceOver journey](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) checks editor labels in both directions and rejects background labels on iOS 27 or later.
iOS 26 SDK builds [exclude the unavailable service](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project#Apply-a-setting-conditionally-to-a-platform-or-architecture) and report a skipped VoiceOver test.
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

Amount input and stored amounts share one whole-yen range.
The parser accepts digits in either width and correctly grouped thousands separators.
The input retains at most 17 Unicode scalars and blocks saving after a rejected edit.
The native field uses [the text field delegate](https://developer.apple.com/documentation/uikit/uitextfielddelegate/textfield(_:shouldchangecharactersinranges:replacementstring:)) to validate edits.
The field accepts the proposed width through [SwiftUI measurement](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:)) to preserve space for clearing input.
Interface journeys check the clear button's size and position with the largest text size and an open keyboard.
Hosted tests exercise replacement, deletion, noncontiguous ranges, and changes that bypass the delegate.
The input follows Apple's [dynamic validation guidance](https://developer.apple.com/design/human-interface-guidelines/entering-data).
Interface tests cover estimates, current rent, and renewal rent through rejection, correction, and saving.
Stored amount tests corrupt each amount slot independently and verify that failed reads preserve the bytes.
Notification fixtures place the next visit relative to the supplied clock instead of a fixed calendar date.
Native journeys check a future visit with denied notifications and an expired visit that remains saved.

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

Use the processed TestFlight build for the physical demonstration.
Use the physical device destination when building the signed runner: `mise x -- just review-journey-build /absolute/path/build`.
Install the runner without replacing the TestFlight app.
Prepare a copy of the generated test-run file with only the interface-test target.
Apple's installed manual describes destination artifacts: `man xcodebuild.xctestrun`.
Xcode supports destination artifacts on physical iOS devices.
Turn on the destination artifact flag: `UseDestinationArtifacts`.
Supply the installed runner and app bundle identifiers plus the test bundle's destination-relative path.
Remove the paths on the host for the app, runner, and test bundle.
Turn off the app's Main Thread Checker.
Run the prepared file with `mise x -- just review-journey-test /absolute/path/installed-app.xctestrun`.
The recipe rejects test-run files that could install another app over the TestFlight build.
