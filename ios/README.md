# Schoolity for iPhone

Native SwiftUI app for iOS 17 and later. Includes required Anoka-Hennepin sign-in, saved sessions, reporting periods, grade history, local what-if editing and target scores, schedule, expandable inbox with senders, and document/mail attachment downloads with Apple's preview and sharing controls. No web view or third-party Swift dependencies.

## Build on GitHub (works from Windows)

Open the repository's **Actions → iOS → Run workflow**. Pushes to `main` that change the iOS app or its server contract also compile automatically; pull requests compile without write permissions or secrets.

The macOS workflow generates the Xcode project, compiles a Release archive for iPhone, runs unit and native UI tests on an installed iPhone simulator, and uploads:

- `Schoolity-iOS-<run>`: unsigned device `.xcarchive.zip` and simulator `.app.zip`.
- `Schoolity-iOS-tests-<run>`: build logs, XCTest results, and synthetic-data simulator screenshots.

Artifacts expire after seven days. An unsigned archive is **not an installable IPA**. This workflow needs no Apple account, certificates, or repository secrets. It does use GitHub-hosted macOS runner minutes; availability follows your account's Actions allowance.

## Open in Xcode

On a Mac with Xcode and Homebrew:

```sh
brew install xcodegen
cd ios
xcodegen generate
open Schoolity.xcodeproj
```

Choose the `Schoolity` scheme and an iPhone simulator, then Run. For an actual iPhone, choose your Apple development team under **Signing & Capabilities** and a bundle identifier you own. Xcode manages signing for local device builds. Distribution through TestFlight or the App Store requires Apple Developer membership and App Store Connect setup; these are not configured here.

`project.yml` is the source of truth; the generated `.xcodeproj` is ignored. The app targets iPhone (also runs in iPhone compatibility mode on iPad); it does not claim a separate iPad layout.

## Server and privacy

`PortalClient.baseURL` is fixed to `https://schoolity-jet.vercel.app`. The existing Schoolity server forwards credentials to the fixed Anoka district and stores the district access token on the server. No server secrets belong in the app. Native POSTs include the fixed server Origin header; the web app retains its same-origin checks.

Native reads opt into `{ "normalized": true }` on `/api/portal`, receiving the same decoded display models as the web interface. Raw responses for existing web callers are unchanged. `/api/documents` still checks ownership and authenticates both document and inbox attachment downloads.

Only the opaque Schoolity session and its expiration are saved in the iOS Keychain, accessible when this device is unlocked and excluded from migration. Passwords, school records, and responses are not saved. Networking uses an ephemeral URLSession without a disk cache or cookie jar; redirects are refused. Sign-out and expired sessions clear visible records, the Keychain entry, and temporary downloaded copies. Files explicitly exported through Apple's share sheet remain wherever the user saved them. Downloaded files have iOS complete file protection.

Internet access and a live Schoolity deployment are required. An expired district session requires another sign-in. Transient read failures retain the current screen and offer Retry. Estimates are independent calculations, not district grades; they never write back to school records. What-if edits last only while the course screen is open.

## Verification

Unit coverage includes points/weighted calculations, excluded and ungraded work, zero and extra credit, category redistribution, target scores, chronology, decoded API models, session expiry, and filename safety. UI tests use original synthetic records in DEBUG builds only; Release has no test/demo entry point. Tests cover login gating, gradebook/chart navigation, what-if editing, collapsed messages/senders, and light/dark screenshots, including large-text login.

Successful compilation and fixture tests do not verify real district credentials, live files, physical-device behavior, or App Store readiness. Real-account compatibility should be checked privately on a signed device build.
