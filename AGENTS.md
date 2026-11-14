# Project contract

Build the iPhone and iPad app for iOS 26 or later with Apple's system design and system indigo.
Support resizable windows and iPhone Duo with native adaptive navigation.
Use native SwiftUI navigation, lists, forms, sheets, and text styles.
Keep glass materials in system controls and navigation.
Keep records and attachments on the device.
The app has Actions, Properties, and Contacts tabs, without cash flow, payments, accounts, or shared editing.
Manage shared contacts and explicit contract deadlines with local reminders.
Product copy is Japanese, and source names and documentation are English.

# Checks

Use `mise x -- just check` for the fast gate and `mise x -- just ui-test` for simulator journeys.
Use `mise x -- just app-test` for foreground recovery and native notification trigger checks.
Use `mise x -- just sanitize` for race instrumentation and `mise x -- just mutation-scan` for mutation analysis.
Follow docs/verification.md for bounded model coverage, isolated mutation inputs, and inconclusive results.
Use `mise x -- just generate` after changing the Xcode project specification.
Don't commit or publish without explicit user instruction.
