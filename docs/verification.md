# Verify record integrity and reminder recovery

The fast gate runs semantic lint, secret scanning, Swift 6 type checking, deterministic tests, and a simulator build.
Xcode builds turn off compilation caching to reduce temporary disk use during checks.
The interface suite exercises saved records through native controls and audits accessibility.
Run the rotation checks on iPad and iPhone Duo simulators with `mise x -- just adaptive-ui-test`.
Run window resizing with the selected record and an open editor, and verify the same title, draft value, and reachable save action afterward.
Keep physical-device acceptance and the App Review recording separate from simulator results.
Selected-row tests audit foreground contrast within the visible selection in both appearances.
Appearance-sensitive journeys use the Simulator profile configured before the run.
The journeys check the rendered background before measuring selected rows or capturing store images.
Hosted layout tests render the contact, work, building, room, and contract detail screens at widths of 320, 420, 600, and 1,024 points.
Tests that create UIKit windows share one [serialized suite](https://developer.apple.com/documentation/testing/parallelization).
The suite keeps scene presentation and text-size changes separate between tests.
The 80 cases cover Light and Dark appearance with standard and AX5 text.
The tests measure rendered separator positions and require aligned metadata rows.
Measurement rejects missing or ambiguous lines.
Icon-bearing metadata rows use Apple's [separator alignment guide](https://developer.apple.com/documentation/swiftui/horizontalalignment/listrowseparatorleading) to align their dividers with the content edge.
Selected rows use the primary system label for text and status symbols.
The style adjusts for its [highlighted background](https://developer.apple.com/documentation/swiftui/environmentvalues/backgroundprominence).
The iPadOS 27.2 audit reports insufficient contrast for a selected deadline whose captured black text has a measured ratio of 12.298:1.
The test also measures the current status and deadline screenshots using the sRGB luminance and contrast formula from the [Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/TR/WCAG22/#dfn-relative-luminance).
The measurement covers captions drawn with a single foreground color on an opaque background.
Status symbols use [monochrome rendering](https://developer.apple.com/design/human-interface-guidelines/sf-symbols#Rendering-modes).
The test groups background colors within one 8-bit step per channel and uses the lowest contrast for the group.
Section headers use the image border to measure an opaque shaded background.
The measurement rejects border channel differences greater than 16 on the 8-bit scale and requires background colors to cover most pixels.
Gradient fixtures reject weak text, missing foreground, and unsupported background variation.
Unsupported or ambiguous images fail verification.
The audit filter requires the affected OS, issue type, label, element type, selection, matching frame, and a fresh measured ratio of at least 4.5:1.
The filter also verifies work titles and the combined progress headers from current screenshots.
Contact captions and section headers receive the same checks.
The information sheet measures its storage text, both website link labels, and copyright text while each caption is fully visible.
Its filter accepts an offscreen contrast report only when the native label and dimensions still match the measured caption.
Unknown reports remain failures.
The reminder tests reveal offscreen captions before measuring contrast.
The audit starts after restoring the original scroll position.
On iPadOS 26.0 and 27.2, native repair, renewal, and building sheets can report unlocated text behind the sheet.
The history, room, and contract editors reproduce the report on iPadOS 27.2.
The schedule editor reproduces it on iPadOS 26.0 with labeled native date and notification controls.
The equipment editor reproduces it on iPadOS 26.0 with readable name and model fields.
The same text report occurs in Files' Connect to Server sheet and an independent SwiftUI form, including with its background hidden from accessibility.
The qualifier requires the exact OS, text-report description, editor screen, floating form bounds, readable labeled inputs, and reachable Save and Cancel controls.
Most qualified editors accept at most one unlocated text report per audit.
The repair editor on iPadOS 26.0 and the renewal editor on iPadOS 27.2 accept at most two, matching their reproduced reports.
Located elements, other issue descriptions, unexpected report counts, and unknown contexts remain failures.
Predicate fixtures reject unsupported versions, other screens, empty or invalid bounds, and an unreadable editor.
[Apple's issue-handler example](https://developer.apple.com/videos/play/wwdc2023/10035/?time=597) supports filtering a specific contrast false positive after checking the label.
The screen tour also audits contrast with Increase Contrast enabled.
Active and completed records share one searchable list.
A regression measures both section headings from their rendered screenshots and requires at least 4.5:1.
The iPadOS 27.2 Documents and Building audits can flag their sidebar section headers despite a measured ratio of 5.245:1.
The header qualifier requires the exact OS, recognized sidebar header, owning list, matching native element, and a fresh measurement of at least 4.5:1.
Unselected record metadata uses primary content colors with [Increase Contrast](https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast).
Its native regression measures work and property captions and requires at least 4.5:1.
At AX5 on iPadOS 27.2, native adaptive tabs can report partial Dynamic Type support without a located element.
An independent SwiftUI TabView reproduces the same report, while Settings' General title reports partial support with a located element.
The qualifier for native tabs requires the exact runtime, AX5, three native tabs at the top, an unlocated report of partial support, and at most three reports.
Located issues, full unsupported reports, and unknown contexts remain failures.
Editor sheets use Apple's [page presentation sizing](https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:)) to keep the available space at AX5.
The repair journey audits the initial form and the amount field after scrolling.
Full unsupported Dynamic Type reports remain failures.
On iOS 27.2, a Japanese development region reproduces clipped-text predictions for complete captions in an independent SwiftUI form.
The caption qualifier requires the exact runtime, report, screen, label, text style, and largest text size.
It checks a unique matching native element, an unobscured viewport, fresh rendered foreground pixels, and the complete text's bounds using the system font.
Its tolerance is one display pixel.
Rejecting fixtures cover other runtimes and reports, unknown captions, insufficient width and height, invalid geometry, overlapping bars, missing pixels, and duplicate elements.
Date inputs show their complete values in [labeled content](https://developer.apple.com/documentation/swiftui/labeledcontent).
The field opens Apple's [graphical calendar](https://developer.apple.com/documentation/swiftui/graphicaldatepickerstyle) in a [popover](https://developer.apple.com/documentation/swiftui/view/popover(ispresented:attachmentanchor:arrowedge:content:)), which adapts to a sheet on iPhone.
Hosted tests recognize both contract dates at standard and AX5 text sizes with language correction turned off.
A truncated native label is a rejecting fixture.
Pixel tests measure rendered date text at widths of 320, 420, and 1,032 points in Light and Dark appearance.
AX5 date text must reach at least twice its standard height.
A forced standard text size must fail the pixel comparison.
Calendar journeys check selection, discarded drafts, saving, relaunch, and accessibility.
Date clipping reports fail verification.
Complementary Light and Dark AX5 journeys check long property names, visible keyboards, discard, save retry, bounded repair estimates, and contract amounts.
Rendered label measurements require the complete label inside its scroll viewport.
A [VoiceOver journey](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) checks editor labels in both directions and rejects background labels on iOS 27 or later.
iOS 26 SDK builds [exclude the unavailable service](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project#Apply-a-setting-conditionally-to-a-platform-or-architecture) and report a skipped VoiceOver test.
Run the interface suite on iOS 26 and an available later runtime after changing app behavior.
The on-demand Native acceptance workflow checks an iPhone with iOS 26 and an iPad with iPadOS 27 through `just ui-test`.
Each target also runs with the largest text size, Dark appearance, and Increase Contrast enabled.
Use GitHub's [documented standard runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) with the installed [Xcode 26](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md) and [Xcode 27](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) environments.
Start a same-repository pull request's run by adding the label: `release-acceptance`.
Remove and reapply the label to check a later head.
The workflow also supports dispatching a selected candidate after the workflow reaches the default branch.
Ordinary commits don't launch the heavy workflow.
At most two jobs run concurrently, and each job stops after 110 minutes.
The interface step stops after 80 minutes, leaving time to preserve results before the job limit.
The native test results and captures remain available for seven days.
An interrupted or timed-out run supplies no passing result.
When the Settings app lacks notification controls in Simulator, combine native denial and foreground journeys with hosted tests of the app's foreground handler using a controlled notification port.
The hosted tests also construct Apple's calendar trigger to check the absolute date across time zones.
The reminder outcome identifies the Actions and Repair lists.
Notification messages and recovery buttons share a row using a [vertical stack](https://developer.apple.com/documentation/swiftui/vstack).
The buttons remain separate controls at least 44 points tall.
[SwiftUI view identity](https://developer.apple.com/documentation/swiftui/view/id(_:)) resets state when its value changes.
Interface tests check notification guidance after launch, after saving, and after dismissal at the selected text size.

The transition tests cover all three-command sequences over seven commands for each work kind.
The 1,029 traces cover 3,087 transitions through production status, relocation, and renewal operations.
The model compares linked records and search membership with independently updated expected records.
The finite bound isn't a proof over arbitrary operation histories.
Controlled continuations test overlapping storage and notification operations without sleeps.
Real temporary files test atomic replacement, file size boundaries, corrupted snapshots, and rejected symbolic links.
Snapshots in format 1 decode into format 2 without rewriting the original file until a successful save.
Contact tests cover categories, emergency ordering, normalized search, shared building links, and reference cleanup on deletion.
Contract notice tests cover explicit dates, calendar-month calculations, leap years, daylight saving, advance notices, and changed deadlines.
Travel tests keep contract calculations in Japan time while work deadlines use the supplied calendar.
Contact destination tests preserve full-width telephone digits and encode mailbox characters without adding message headers.
Typed notification targets keep room and work records distinct even when their identifier values match.
Hosted tests check permission recovery without another record write and defer notification navigation while an editor remains open.

Amount input and stored amounts share one whole-yen range.
The input shows one editable amount without repeating its value below the field.
The parser accepts digits in either width and correctly grouped thousands separators.
The input retains at most 17 Unicode scalars and blocks saving after a rejected edit.
The native field uses [the text field delegate](https://developer.apple.com/documentation/uikit/uitextfielddelegate/textfield(_:shouldchangecharactersinranges:replacementstring:)) to validate edits.
The field keeps the standard number pad and [disables its popover](https://developer.apple.com/documentation/uikit/uitextinputtraits/allowsnumberpadpopover) to prevent the popup from intercepting editor actions on iPad.
Native journeys clear and save amounts before and after keyboard focus.
The journeys wait for stable native editor and keyboard frames before the next action.
Editor frame checks capture the input, keyboard, and toolbar in one [native snapshot](https://developer.apple.com/documentation/xcuiautomation/xcuielementsnapshotproviding/snapshot()) before comparing their positions.
Scroll checks calculate the visible viewport from native navigation and tab bars.
The field accepts the proposed width through [SwiftUI measurement](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:)) to preserve space for clearing input.
Interface journeys check the clear button's size and position with the largest text size and an open keyboard.
Hosted tests exercise replacement, deletion, noncontiguous ranges, and changes that bypass the delegate.
The input follows Apple's [dynamic validation guidance](https://developer.apple.com/design/human-interface-guidelines/entering-data).
Interface tests cover estimates and current rent through rejection, correction, and saving.
Stored amount tests corrupt each amount slot independently and verify that failed reads preserve the bytes.
Notification fixtures place deadlines and stored visit dates relative to the supplied clock instead of a fixed calendar date.
Native journeys check a future deadline with denied notifications and an expired deadline that remains saved.

Short memos keep the existing history format while removing communication fields from the form.
Native journeys add and edit memos.
Search and relaunch checks verify persistence in the combined progress list.
Property screens keep property editing in their own tab.
Photographs render within their records, and stored documents remain readable without a new file-import action.
Image I/O tests cover orientation, bounded dimensions, invalid input, source size limits, and rejected symbolic links.
Normalized photographs omit source location metadata.
External URL tests cover cancellation, exact destination handoff, native telephone confirmation, and document-preview delegation.
Sheet journeys keep the presenting screen open after cancellation and return to it after a confirmed browser handoff.

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
The journey has a ten-minute limit for native controls, record creation, and rotation checks.
The recipe rejects test-run files that could install another app over the TestFlight build.
