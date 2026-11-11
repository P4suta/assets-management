# Property records

Property Records is a Japanese iPhone app for repair follow-up and local property records.
It targets iOS 26 or later and has Actions and Properties tabs.
Cash flow, payments, accounts, and shared editing are outside the selected scope.

## Use the app

Add a building and its first room from Properties.
Register contracts, residents, equipment, and documents from each room.
Add repairs, renewals, or inspections from Actions or from a building or room.
Common-area work belongs to the building without a room.
The work states are `Not Started`, `In Progress`, `Waiting`, `Completed`.
Renewal drafts keep the signed contract unchanged until explicit confirmation.

Records and copied attachments stay in the app's private container.
The app requests camera access only when taking a photograph and notification access only when saving a reminder.
Denied notification access still permits saving a schedule.
The app imports `.pdf`, `.txt`, `.jpg`, `.jpeg`, `.png`, and `.heic` files.
The limit is 25 MB per file.
Photos use the system picker, and documents open in the system viewer.
The app has no analytics or network service.

## Build and check

Install Xcode with the iOS 26 SDK or later and the tools pinned in mise.toml.
Run mise install and mise x -- just generate, then open PropertyRecords.xcodeproj.
Choose a simulator and run the PropertyRecords scheme.
A physical-device build also needs the owner's signing team in Xcode.

Run mise x -- just check for lint, secret scanning, domain tests, storage tests, source policy checks, and a simulator build.
Run mise x -- just ui-test for native interaction tests and the screen tour.
Set SIMULATOR_DESTINATION to an available Xcode destination to select another simulator.
Run mise x -- just release-build for an unsigned device build.
The simulator tour records screenshots and audits accessibility.
Repeat the tour in Light and Dark, with Increase Contrast, and at the largest text size using the dedicated simulator's simctl ui settings.

## Design and storage

The [Figma file](https://www.figma.com/design/2c0UBJAaqTU8hu2oNlymtE/?node-id=38-14258) contains the editable screens and journeys.
[Apple's adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) governs native navigation and controls.
[Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) governs text, status labels, and contrast variants.
The app uses native fonts and control metrics.
The Figma Japanese font fallback is Noto Sans JP, while the app uses the system's Japanese font.

The domain package validates required fields, references, room numbers, dates, and amounts before persistence.
An actor writes a versioned snapshot atomically and publishes the change after success.
Attachment imports copy files before saving metadata and remove the new file if the metadata commit fails.
[The storage decision](docs/adr/native-records-with-atomic-local-storage.md) describes the chosen boundary.

## Sample photograph

Debug interface tests use fictional property records and a photograph by drake035 from Home Improvement Stack Exchange.
The photograph has no edits and uses the `CC BY-SA 3.0` license.
The source and license links are in App/Resources/PhotoLicense.txt.
Ordinary app launches start without sample records.
