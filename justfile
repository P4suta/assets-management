destination := env("SIMULATOR_DESTINATION", "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0")
derived_data := env("PROPERTY_RECORDS_DERIVED_DATA", ".derivedData")

default:
    @just --list

generate:
    xcodegen generate

lint:
    swiftlint lint --strict --quiet
    gitleaks dir . --config .gitleaks.toml --no-banner --redact --exit-code 1
    jactionlint
    zizmor --offline .github/workflows

test:
    swift test

sanitize:
    swift test --sanitize thread --jobs 2 --scratch-path .build/thread-sanitizer

[private]
mutation-results:
    @mkdir -p .results

mutation-plan: mutation-results
    swift-mutation-testing plan --output .results/mutation-plan.json

mutation-scan: mutation-results
    swift-mutation-testing run

build: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build -quiet

check: lint test build website-check store-assets

website-check:
    cd website && mise x node aqua:pnpm/pnpm just -- just check

website-ui-test:
    cd website && mise x node aqua:pnpm/pnpm just -- just ui-test

app-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:PropertyRecordsAppTests test -quiet

camera-sanitize result_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath .results/camera-encoding-sanitizer-derivedData -jobs 2 CODE_SIGNING_ALLOWED=NO -enableThreadSanitizer YES -parallel-testing-enabled NO -only-testing:PropertyRecordsAppTests/PhotoProcessorTests -resultBundlePath '{{ result_path }}' test -quiet
    xcrun xcresulttool get test-results summary --path '{{ result_path }}' | jaq --exit-status '.result == "Passed" and .totalTestCount == 7 and .passedTests == 7 and .failedTests == 0 and .skippedTests == 0'

vision-test result_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsVisionCapture -destination '{{ destination }}' -derivedDataPath .results/vision-compatible-derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -resultBundlePath '{{ result_path }}' test
    just native-text-test '{{ result_path }}'

vision-ui-test result_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsVisionInterface -destination '{{ destination }}' -derivedDataPath .results/vision-interface-derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600 '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testAddActionsOpenAndCancelEditors()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testPropertyRegistrationPersistsAfterRelaunch()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testRepairPhotographsAreVisibleInlineWithoutFilenames()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testShortMemosCanBeAddedAndEditedInline()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testContactEmailConfirmsTheAddressAndKeepsTelephoneNotesReadable()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testCompatibleVisionCallsRequireConfirmationBeforeHandoff()' -resultBundlePath '{{ result_path }}' test
    xcrun xcresulttool get test-results summary --path '{{ result_path }}' | jaq --exit-status '.totalTestCount == 6 and .passedTests == 6 and .failedTests == 0 and .skippedTests == 0'

native-text-test result_path:
    xcrun xcresulttool export attachments --path '{{ result_path }}' --output-path '{{ result_path }}.captures'
    xcodebuild -project PropertyRecords.xcodeproj -scheme NativeTextValidation -destination 'platform=macOS,arch=arm64' -derivedDataPath .results/native-text-validation-derivedData -parallel-testing-enabled NO 'NATIVE_TEXT_CAPTURE_PATH={{ absolute_path(result_path) }}.captures' -resultBundlePath '{{ result_path }}.recognition.xcresult' test

mac-ui-test app_path result_path: generate
    test "$(plutil -extract CFBundleIdentifier raw -o - '{{ app_path }}/WrappedBundle/Info.plist')" = com.p4suta.PropertyRecords
    codesign --display --entitlements - --xml '{{ app_path }}' | plutil -convert json -o - - | jaq --exit-status '."get-task-allow" == true'
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsMacInterface -destination 'platform=macOS,arch=arm64' -derivedDataPath .results/mac-compatible-interface-derivedData -parallel-testing-enabled NO 'MAC_COMPATIBLE_APP_PATH={{ absolute_path(app_path) }}' -resultBundlePath '{{ result_path }}' test

mac-app-test result_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination 'platform=macOS,arch=arm64' -derivedDataPath .results/mac-compatible-derivedData -parallel-testing-enabled NO DEVELOPMENT_TEAM=XMBQLW82L9 -allowProvisioningUpdates -only-testing:PropertyRecordsAppTests -resultBundlePath '{{ result_path }}' test

ui-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSystemSettingsAuditProbe()' test

ui-workflow-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSystemSettingsAuditProbe()' '-skip-testing:PropertyRecordsUITests/AdaptiveRecordLayoutTests' '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility()' '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedWorkAndUnsavedEditSurviveRotation()' '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testBuildingRoomContactAndEquipmentEditsSurviveRelaunch()' '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testContactDirectoryCanClassifySearchAndDeleteASharedContact()' '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedRecordRowsRemainReadable()' test

ui-layout-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/AdaptiveRecordLayoutTests' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedWorkAndUnsavedEditSurviveRotation()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testBuildingRoomContactAndEquipmentEditsSurviveRelaunch()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testContactDirectoryCanClassifySearchAndDeleteASharedContact()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedRecordRowsRemainReadable()' test

ui-tour: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility()' test -quiet

adaptive-ui-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedWorkAndUnsavedEditSurviveRotation()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedPropertyAndRoomSurviveRotation()' test -quiet

store-screenshot-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath '{{ derived_data }}' CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testStoreScreenshots()' test -quiet

review-journey-build build_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsReview -configuration Release -destination '{{ destination }}' -derivedDataPath '{{ build_path }}' DEVELOPMENT_TEAM=XMBQLW82L9 -allowProvisioningUpdates build-for-testing -quiet

review-journey-test run_file:
    plutil -convert json -o - '{{ run_file }}' | jaq --exit-status '((keys | sort) == ["PropertyRecordsUITests", "__xctestrun_metadata__"]) and .PropertyRecordsUITests.UseDestinationArtifacts == true and .PropertyRecordsUITests.UITargetAppBundleIdentifier == "com.p4suta.PropertyRecords"'
    xcodebuild -xctestrun '{{ run_file }}' -destination '{{ destination }}' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600 '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testReviewDemonstration()' test-without-building -quiet

release-build: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build -quiet

archive archive_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .derivedData -jobs 2 -archivePath '{{ archive_path }}' -allowProvisioningUpdates archive -quiet
    just archive-resources '{{ archive_path }}'

export archive_path output_path:
    just archive-resources '{{ archive_path }}'
    PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive -archivePath '{{ archive_path }}' -exportPath '{{ output_path }}' -exportOptionsPlist AppStore/ExportOptions.plist -allowProvisioningUpdates -quiet

archive-resources archive_path:
    test ! -e '{{ archive_path }}/Products/Applications/PropertyRecords.app/PhotoLicense.txt'
    xcrun assetutil --info '{{ archive_path }}/Products/Applications/PropertyRecords.app/Assets.car' | jaq --exit-status --slurp 'length == 1 and (.[0] | type == "array" and length > 0 and all(.[]; .Name? != "FixturePhoto"))'

store-assets:
    jaq --exit-status '.keywords as $text | if ($text | length) <= 100 and ($text | utf8bytelength) <= 100 and ($text | split(",") | all(.[]; length > 2)) then true else error("Keywords require at most 100 characters and 100 UTF-8 bytes, with each term longer than two characters.") end' AppStore/Metadata/version/*/*.json
    asc metadata validate --dir AppStore/Metadata
    asc screenshots validate --path AppStore/Screenshots/ja/APP_IPHONE_69 --device-type APP_IPHONE_69
    asc screenshots validate --path AppStore/Screenshots/ja/APP_IPHONE_61 --device-type APP_IPHONE_61
    asc screenshots validate --path AppStore/Screenshots/ja/APP_IPAD_PRO_3GEN_129 --device-type APP_IPAD_PRO_3GEN_129
