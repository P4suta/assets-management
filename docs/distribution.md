# Prepare distribution

The app targets iPhone and iPad with iOS 26 or later.
Its native layout supports resizable windows and iPhone Duo.
The App Store name is `物件管理くん`.
The price is free, with no accounts, advertising, tracking, or purchases.
The bundle identifier is `com.p4suta.PropertyRecords`.
The Apple Developer team is `XMBQLW82L9`.
The initial version is `1.0.0`.
The current build number is `3`.

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

The Japanese description addresses rental property managers who need repair history, scattered documents, and renewal terms in one place.
Its examples describe contact history, search, renewal drafts, reminders, equipment, and common-area work that the app supports.
The promotional text describes the history users can keep.
The marketing URL points to the app-specific landing page at its subdomain root.
The [header artwork](../AppStore/CreativeAssets/ja/header.svg) and [search results artwork](../AppStore/CreativeAssets/ja/search-results.svg) contain the Japanese heading on a white background.
The header uses 3840 by 1646 pixels, and the search artwork uses 3840 by 2560 pixels under Apple's [creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications).
Each heading stays inside its template's safe area.
The header's safe area starts at x=1097, y=493 with width=1646 and height=661.
The search artwork's safe area starts at x=836, y=765 with width=2168 and height=1030.

Render the SVG from its directory with ImageMagick 7 and a path to the macOS Yu Gothic Bold font:

```sh
magick -font "$STORE_CREATIVE_FONT" header.svg -background white -alpha remove -alpha off -colorspace sRGB -strip -define png:color-type=2 header.png
magick -font "$STORE_CREATIVE_FONT" search-results.svg -background white -alpha remove -alpha off -colorspace sRGB -strip -define png:color-type=2 search-results.png
```

For Japanese, upload both opaque images to Asset Library.
Assign the header to `PRODUCT_PAGE_HEADER_ASSET`.
Assign the search artwork to `APP_STORE_SEARCH_RESULTS_ASSET`.
For the initial version, add the app version to a draft after assigning its creative images.
Check the image's review state before adding a separate asset item.
Leave the draft ready when the user requests a manual submission.

Prepare the Japanese metadata, screenshots, free price, age rating, export compliance, privacy answers, and review notes under [Apple's version requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).
Select [automatic release after approval](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option) after the user authorizes publication.
Upload and build processing are preparation steps.
Submitting for App Review and releasing the app require explicit authorization.
