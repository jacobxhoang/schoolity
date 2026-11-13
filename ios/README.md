# Schoolity for iPhone

Native SwiftUI app for iOS 17 and later. Includes required Anoka-Hennepin sign-in, saved sessions, reporting periods, grade history, local what-if editing and target scores, schedule, expandable inbox with senders, and document/mail attachment downloads with Apple's preview and sharing controls. No web view or third-party Swift dependencies.

## Saved sign-in and Face ID

Sign in once with your school username and password. On a device with a passcode, Schoolity saves the session and credentials in a protected, device-only Keychain entry, immediately requests local authentication (including the iOS Face ID permission when applicable), and reads the saved entry back before displaying records. Cancelling leaves the original saved-sign-in retry screen. Reopening the app shows the original saved-sign-in screen. Face ID, Touch ID, or the device passcode starts automatically on launch and after a real background/foreground transition; credentials do not need to be retyped. If you cancel or a connection fails, **Sign in** retries without another automatic prompt loop. If the school session expired, the same authenticated operation signs in again using the saved credentials. Allow Face ID when iOS asks. Cancelling keeps sign-in saved for retry. **Sign in again** and **Sign out** erase the saved session and credentials.

Schoolity locks when sent to the background, clears displayed records and temporary downloads, and automatically authenticates on return. The app covers its main content while inactive. Apple's own authentication prompt does not cause an unlock loop. A rejected saved password returns to school credentials; transient network errors retain the protected entry for retry. Late network responses cannot activate a backgrounded workspace or restore an explicitly forgotten account. Backgrounding during a passcode-free startup check invalidates that attempt; returning restarts it with the saved cookie, so startup cannot remain stranded.

A separate device-only Keychain item stores only discovery flags and expiry, never the username, password, or cookie. Startup can discover saved sign-in without reading a protected secret. Authentication restrictions or temporary Keychain errors do not mean the account is missing and must not delete it. An unreadable entry stays available for retry rather than being silently erased. Old attribute-only metadata is migrated after authentication.

Existing saved sessions are upgraded to require local authentication on the first successful unlock. Devices without a passcode retain the original saved-sign-in behavior; setting up a passcode enables the protected flow on the next reopen. Protected sessions are never retrieved without successful local authentication, even if biometrics become unavailable. Face ID permission denial can fall back to the device passcode or school credentials. Removing the device passcode invalidates protected Keychain entries.

Older installations stored only a session. Enter your school credentials once after updating to enable renewal; a password cannot be recovered from an old session. Devices without a passcode save only the expiring session, never the password.

## Native interface

The original Schoolity credential form and saved-sign-in screen are retained, now with a teal accent for primary actions, selected navigation, grade badges and graph marks. Light Mode uses deep teal (#08666E); Dark Mode uses pale teal (#74D8DE), with neutral system backgrounds and labels. The barcode remains black on white. Saved sign-in starts automatically; **Sign in** remains a retry action. Grades open first; Home is removed, leaving Grades, Schedule, Inbox and Documents. The remaining compact native inset rows, course symbols and stacked grade lines take Pupil as a visual reference. Account displays the student number and barcode directly, with no extra navigation. Charts and local calculators retain their functions. No Pupil source code, images, branding, SwiftVue, or credential-storage dependencies are bundled.

## Build on GitHub (works from Windows)

Open the repository's **Actions → iOS → Run workflow** on `main`. Pushes to `main` that change the iOS app or its server contract also compile automatically. After the tests pass, download **Schoolity.ipa** from the [latest release](https://github.com/verityhoangjacob67/schoolity/releases/latest).

The macOS job generates the Xcode project, compiles an unsigned Release archive for iPhone, and runs unit and native UI tests. Simulator test builds use local ad-hoc signing and simulator-only Keychain entitlements, so tests exercise real Keychain save/reopen/delete and old-entry migration rather than only mocked storage. This local simulator signature does not sign the release IPA for a physical iPhone. A separate release job publishes **only Schoolity.ipa** as the app download, tagged `ios-build-<run>.<attempt>` and marked Latest. The tag targets the tested commit; reruns create a fresh release. The app's build number follows the workflow run number.

Pull requests and manual builds of other branches compile/test without publishing. Build jobs have read-only repository access; only the main-branch release job receives permission to create a release. No Apple credentials or repository secrets are needed.

The release IPA does not expire with Actions artifacts. A one-day internal IPA artifact transfers the file between jobs. Test evidence is retained for one day only on failure, or when **Keep simulator screenshots and test results for one day** is checked for a manual run. No simulator ZIP or archive ZIP is published.

The IPA is **unsigned** and requires Apple signing before installation; downloading it alone will not install it on an iPhone. The workflow uses GitHub-hosted macOS runner minutes; availability follows your account's Actions allowance.

## Student ID

Open **Account** to immediately see the district-provided student number and a black-on-white Code 128 barcode. The value stays text to preserve leading zeros. Summary/detail profile data is combined, using explicit district student-number fields; account usernames, GUIDs, and child indexes are never substituted. If no ID is supplied, the app shows an unavailable state with Retry. Profile and ID data remain in memory and clear when the app locks or signs out.

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

On devices with a passcode, the Keychain entry includes the opaque session, its expiration, and saved school credentials, protected with `userPresence` and `WhenPasscodeSetThisDeviceOnly`. Credentials are read only after successful local authentication and used only during sign-in; the in-memory active session contains no password. Non-secret metadata records whether renewal is possible. Without a passcode, `WhenUnlockedThisDeviceOnly` stores only the session. Neither cookie nor credentials are read during client initialization. School records/responses are not saved. Networking uses an ephemeral URLSession without disk cache or cookie jar; redirects are refused. Native requests do not persist passwords on the server; only the web client's opt-in saved sign-in stores them, encrypted, for up to 30 days. Exported files remain where the user saved them; temporary downloads use complete file protection and clear on lock/sign-out.

Internet access and a live Schoolity deployment are required. An expired district session requires another sign-in. Transient read failures retain the current screen and offer Retry. Estimates are independent calculations, not district grades; they never write back to school records. What-if edits last only while the course screen is open.

## Verification

Unit coverage includes points/weighted calculations, excluded and ungraded work, zero and extra credit, category redistribution, target scores, chronology, decoded API models, session expiry, and filename safety. UI tests use original synthetic records in DEBUG builds only; Release has no test/demo entry point. Tests cover login gating, gradebook/chart navigation, what-if editing, collapsed messages/senders, Schedule, Documents, Account, and light/dark screenshots. Login, the gradebook, and course details are also captured at the largest accessibility text size in Dark Mode.

Successful compilation and fixture tests do not verify real district credentials, live files, physical-device behavior, or App Store readiness. Real-account compatibility should be checked privately on a signed device build.

Saved-sign-in tests inject a local-authentication provider and server client to check success, cancellation, migration, unavailable authentication, expiry/revocation, logout, and background races without real credentials. DEBUG UI fixtures exercise the saved-sign-in screen and password fallback in light/dark appearances; they do not simulate an actual Face ID scan or prove hardware Keychain authentication. Verify Face ID permission, recognition, cancellation, and passcode fallback on a signed iPhone build.
