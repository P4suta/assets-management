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

check: lint test build website-check

website-check:
    cd website && mise x node aqua:pnpm/pnpm just -- just check

website-ui-test:
    cd website && mise x node aqua:pnpm/pnpm just -- just ui-test

app-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:PropertyRecordsAppTests test -quiet

ui-test: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -skip-testing:PropertyRecordsUITests/PropertyRecordsUITests/testSystemSettingsAuditProbe test -quiet

ui-tour: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -destination '{{ destination }}' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -only-testing:PropertyRecordsUITests/PropertyRecordsUITests/testScreenTourAccessibility test -quiet

release-build: generate
    xcodebuild -project PropertyRecords.xcodeproj -scheme PropertyRecords -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build -quiet
