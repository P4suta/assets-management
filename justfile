destination := env("SIMULATOR_DESTINATION", "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0")

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
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build -quiet

check: lint test build website-check store-assets

website-check:
    cd website && mise x node aqua:pnpm/pnpm just -- just check

website-ui-test:
    cd website && mise x node aqua:pnpm/pnpm just -- just ui-test

app-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:PropertyRecordsAppTests test -quiet

ui-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSystemSettingsAuditProbe()' test -quiet

ui-tour: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility()' test -quiet

adaptive-ui-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedWorkAndUnsavedEditSurviveRotation()' '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSelectedPropertyAndRoomSurviveRotation()' test -quiet

store-screenshot-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsInterface -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testStoreScreenshots()' test -quiet

review-journey-build build_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecordsReview -configuration Release -destination '{{ destination }}' -derivedDataPath '{{ build_path }}' DEVELOPMENT_TEAM=XMBQLW82L9 -allowProvisioningUpdates build-for-testing -quiet

review-journey-test run_file:
    plutil -convert json -o - '{{ run_file }}' | jaq --exit-status '((keys | sort) == ["PropertyRecordsUITests", "__xctestrun_metadata__"]) and .PropertyRecordsUITests.UseDestinationArtifacts == true and .PropertyRecordsUITests.UITargetAppBundleIdentifier == "com.p4suta.PropertyRecords"'
    xcodebuild -xctestrun '{{ run_file }}' -destination '{{ destination }}' -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 240 -maximum-test-execution-time-allowance 300 '-only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testReviewDemonstration()' test-without-building -quiet

release-build: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build -quiet

archive archive_path: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .derivedData -jobs 2 -archivePath '{{ archive_path }}' -allowProvisioningUpdates archive -quiet
    just archive-resources '{{ archive_path }}'

export archive_path output_path:
    just archive-resources '{{ archive_path }}'
    xcodebuild -exportArchive -archivePath '{{ archive_path }}' -exportPath '{{ output_path }}' -exportOptionsPlist AppStore/ExportOptions.plist -allowProvisioningUpdates -quiet

archive-resources archive_path:
    test ! -e '{{ archive_path }}/Products/Applications/PropertyRecords.app/PhotoLicense.txt'
    xcrun assetutil --info '{{ archive_path }}/Products/Applications/PropertyRecords.app/Assets.car' | jaq --exit-status --slurp 'length == 1 and (.[0] | type == "array" and length > 0 and all(.[]; .Name? != "FixturePhoto"))'

store-assets:
    asc metadata validate --dir AppStore/Metadata
    asc screenshots validate --path AppStore/Screenshots/ja/APP_IPHONE_61 --device-type APP_IPHONE_61
    asc screenshots validate --path AppStore/Screenshots/ja/APP_IPAD_PRO_3GEN_129 --device-type APP_IPAD_PRO_3GEN_129
