# Develop property records

The iPhone app targets iOS 26 or later and has Actions and Properties tabs.
Records and copied attachments stay in the app's private container.
The app has no analytics or network service.

## Use the app

Read [App support](support.md) for registration, repairs, renewals, files, and reminders.
Read [Privacy policy](privacy-policy.md) for storage, permissions, and backups.

## Build and check

Install Xcode with the iOS 26 SDK or later and the tools pinned in `mise.toml`.
Install the pinned tools with `mise install`.
Generate the Xcode project with `mise x -- just generate`.
Choose a simulator and run the Xcode scheme: `PropertyRecords`.
A physical-device build also needs the owner's signing team in Xcode.

Run the fast gate for lint, secret scanning, domain tests, storage tests, source policy checks, and a simulator build: `mise x -- just check`.
Run native interaction tests and the screen tour: `mise x -- just ui-test`.
Select another simulator by assigning an available Xcode destination to `SIMULATOR_DESTINATION`.
Use [Verification](verification.md) for accessibility profiles, instrumentation, and mutation analysis.
Use [Distribution](distribution.md) for signing and App Store preparation.

## Design and storage

The [Figma file](https://www.figma.com/design/2c0UBJAaqTU8hu2oNlymtE/?node-id=38-14258) contains the editable screens and journeys.
Use [Apple's adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) for native navigation and controls.
Use [Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) for text, status labels, and contrast variants.
The app uses native fonts and control metrics.
The Figma Japanese font fallback is Noto Sans JP, while the app uses the system's Japanese font.

The domain package validates required fields, references, room numbers, dates, and amounts before persistence.
An actor writes a versioned snapshot atomically and publishes the change after success.
Attachment imports copy files before saving metadata and remove the new file if the metadata commit fails.
[The storage decision](adr/native-records-with-atomic-local-storage.md) describes the chosen boundary.

## Sample photograph

Debug interface tests use fictional property records and a photograph by drake035 from Home Improvement Stack Exchange.
The photograph has no edits and uses the license `CC BY-SA 3.0`.
Read the [photo attribution](../App/DevelopmentAssets/PhotoLicense.txt) for the source and license.
Archive builds exclude the development photograph and its license file.
Ordinary app launches start without sample records.
