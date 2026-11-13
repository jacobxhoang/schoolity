# Schoolity for iPhone

Native SwiftUI app for iOS 17 and later. Includes required Anoka-Hennepin sign-in, saved sessions, reporting periods, grade history, local what-if editing and target scores, schedule, expandable inbox with senders, and document/mail attachment downloads with Apple's preview and sharing controls. No web view or third-party Swift dependencies.

## Saved sign-in and Face ID

Sign in once with your school username and password. Schoolity saves the expiring session on this iPhone. On devices with a passcode, reopening the app unlocks that session with Face ID, Touch ID, or the device passcode, using Apple's authentication controls. Allow Face ID when iOS asks. If you cancel, the sign-in stays saved and you can retry. **Sign in again** removes the saved session and returns to school credentials.

Schoolity locks when sent to the background, clears the displayed records and temporary downloads, and unlocks again on return. The app also covers its content while inactive. Apple's own authentication prompt does not cause a new unlock loop. An expired or district-revoked session still needs another school login; Face ID cannot extend the district session.

Existing saved sessions are upgraded to require local authentication on the first successful unlock. Devices without a passcode retain the original saved-sign-in behavior; setting up a passcode enables the protected flow on the next reopen. Protected sessions are never retrieved without successful local authentication, even if biometrics become unavailable. Face ID permission denial can fall back to the device passcode or school credentials. Removing the device passcode invalidates protected Keychain entries.

## Build on GitHub (works from Windows)

Open the repository's **Actions → iOS → Run workflow** on `main`. Pushes to `main` that change the iOS app or its server contract also compile automatically. After the tests pass, download **Schoolity.ipa** from the [latest release](https://github.com/verityhoangjacob67/schoolity/releases/latest).

The macOS job generates the Xcode project, compiles a Release archive for iPhone, and runs unit and native UI tests. A separate release job publishes **only Schoolity.ipa** as the app download, tagged `ios-build-<run>.<attempt>` and marked Latest. The tag targets the tested commit; reruns create a fresh release. The app's build number follows the workflow run number.

Pull requests and manual builds of other branches compile/test without publishing. Build jobs have read-only repository access; only the main-branch release job receives permission to create a release. No Apple credentials or repository secrets are needed.

The release IPA does not expire with Actions artifacts. A one-day internal IPA artifact transfers the file between jobs. Test evidence is retained for one day only on failure, or when **Keep simulator screenshots and test results for one day** is checked for a manual run. No simulator ZIP or archive ZIP is published.

The IPA is **unsigned** and requires Apple signing before installation; downloading it alone will not install it on an iPhone. The workflow uses GitHub-hosted macOS runner minutes; availability follows your account's Actions allowance.

## Student ID

Open **Account → Student ID** to show the district-provided student number and a black-on-white Code 128 barcode. The value stays text to preserve leading zeros. Summary/detail profile data is combined, using explicit district student-number fields; account usernames, GUIDs, and child indexes are never substituted. If no ID is supplied, the app shows an unavailable state with Retry. Profile and ID data remain in memory and clear when the app locks or signs out.

The barcode uses Core Image at integer pixel scales with quiet zones. An automated Vision decoding test checks the exact encoded value. This is a Schoolity display of district data, not a district-issued credential; live Anoka ID-field compatibility and campus scanner acceptance still need private verification. No student photo or manually invented ID is included.

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

Only the opaque Schoolity session, its expiration, and non-secret unlock metadata are saved in the iOS Keychain. Devices with a passcode use a `userPresence` access-control constraint and `WhenPasscodeSetThisDeviceOnly`; retrieving the cookie requires Apple's local authentication. Without a passcode the fallback is `WhenUnlockedThisDeviceOnly`. The cookie is not read during app/client initialization. Passwords, school records, and responses are not saved. Networking uses an ephemeral URLSession without a disk cache or cookie jar; redirects are refused. Sign-out and expired sessions clear visible records, the Keychain entry, and temporary downloaded copies. Files explicitly exported through Apple's share sheet remain wherever the user saved them. Downloaded files have iOS complete file protection.

Internet access and a live Schoolity deployment are required. An expired district session requires another sign-in. Transient read failures retain the current screen and offer Retry. Estimates are independent calculations, not district grades; they never write back to school records. What-if edits last only while the course screen is open.

## Verification

Unit coverage includes points/weighted calculations, excluded and ungraded work, zero and extra credit, category redistribution, target scores, chronology, decoded API models, session expiry, and filename safety. UI tests use original synthetic records in DEBUG builds only; Release has no test/demo entry point. Tests cover login gating, gradebook/chart navigation, what-if editing, collapsed messages/senders, Schedule, Documents, Account, and light/dark screenshots. Login, the gradebook, and course details are also captured at the largest accessibility text size in Dark Mode.

Successful compilation and fixture tests do not verify real district credentials, live files, physical-device behavior, or App Store readiness. Real-account compatibility should be checked privately on a signed device build.

Saved-sign-in tests inject a local-authentication provider and server client to check success, cancellation, migration, unavailable authentication, expiry/revocation, logout, and background races without real credentials. DEBUG UI fixtures exercise the saved-sign-in screen and password fallback in light/dark appearances; they do not simulate an actual Face ID scan or prove hardware Keychain authentication. Verify Face ID permission, recognition, cancellation, and passcode fallback on a signed iPhone build.
