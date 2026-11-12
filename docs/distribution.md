# Prepare distribution

The app targets iPhone with iOS 26 or later.
The App Store name is `物件管理くん`.
The price is free, with no accounts, advertising, tracking, or purchases.
The bundle identifier is `com.p4suta.PropertyRecords`.
The Apple Developer team is `XMBQLW82L9`.
The initial version is `1.0.0`.
The current build number is `2`.

Run the fast gate, hosted app tests, interface journeys on iOS 26 and a later runtime, Thread Sanitizer, and the full mutation campaign before archiving.
The verification scope and mutation acceptance criteria are in [verification.md](verification.md).
Use a clean committed source state for the distribution candidate.

Create the signed archive with `mise x -- just archive /absolute/path/PropertyRecords.xcarchive`.
Export the preserved archive with `mise x -- just export /absolute/path/PropertyRecords.xcarchive /absolute/path/export`.
Check that the archive excludes development fixtures: `mise x -- just archive-resources /absolute/path/PropertyRecords.xcarchive`.
Xcode excludes the [development assets](https://developer.apple.com/documentation/xcode/build-settings-reference#Development-Assets) from archive and install builds.
The export options select App Store Connect distribution with automatic signing and preserve the declared build number.
The export command creates an iOS App Store Package (IPA) without uploading it.
Apple describes the [archive and distribution stages](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

Run the signature check on the exported app: `codesign --verify --deep --strict`.
Inspect its signing authority, entitlements, embedded profile, bundle identifier, deployment target, and version.
App Store distribution requires an Apple Distribution identity from the declared team and a distribution profile for the exact bundle identifier.
The debugging entitlement must be false.
Development signing alone doesn't pass the distribution check.
Inspect the package offline with `mise x -- asc ipa-info --path /absolute/path/PropertyRecords.ipa --include-profile --include-entitlements --verify-signature`.

The public privacy URL is [Privacy policy](https://assets-management.yasunobu.dev/privacy/).
The public support URL is [Support](https://assets-management.yasunobu.dev/support/).
App Store privacy answers must describe the shipped binary and its dependencies.
The app stores records and attachments on the device and has no collection service.
The support email is `hi@sakashita.email`.

The Japanese description explains repair and renewal records without a tab walkthrough.
The promotional text describes the history users can keep.
The [editable creative image](../AppStore/CreativeAssets/ja/property-records.svg) uses the native Actions and Properties screenshots.
Its heading stays inside the universal template's safe area at x=1921, y=660, width=1402, and height=962.
The native screenshots keep Apple's system colors.
The header and search results share an opaque 5244 by 2950 pixel image under Apple's [creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications).

Render the SVG from its directory with ImageMagick 7 and a path to the macOS Yu Gothic Bold font:

```sh
magick -font "$STORE_CREATIVE_FONT" property-records.svg -background white -alpha remove -alpha off -colorspace sRGB -strip -define png:color-type=2 property-records.png
```

For Japanese, upload the image to Asset Library and assign it to `PRODUCT_PAGE_HEADER_ASSET` and `APP_STORE_SEARCH_RESULTS_ASSET`.
For the initial version, add the app version to a draft after assigning its creative image.
Check the image's review state before adding a separate asset item.
Leave the draft ready for the final submission button when the owner requests that handoff.

Prepare the Japanese metadata, screenshots, free price, age rating, export compliance, privacy answers, and review notes under [Apple's version requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).
Select [automatic release after approval](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option) when the owner authorizes publication.
Upload and build processing are preparation steps.
Submitting for App Review and releasing the app require the owner's instruction.
