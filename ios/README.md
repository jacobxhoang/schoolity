# Schoolity for iPhone

Native SwiftUI app for iOS 17 and later. Includes required Anoka-Hennepin sign-in, saved sessions, reporting periods, grade history, local hypothetical editing, term-aware schedule, student information, attendance, course history with graduation progress and subject details, expandable inbox with senders, and document/mail attachment downloads with Apple's preview and sharing controls. No web view or third-party Swift dependencies.

## Saved sign-in and Face ID

Sign in once with your school username and password. On a device with a passcode, Schoolity saves the session and credentials in a protected, device-only Keychain entry, immediately requests local authentication (including the iOS Face ID permission when applicable), and reads the saved entry back before displaying records. Cancelling leaves the original saved-sign-in retry screen. A full app restart restores saved sign-in with Face ID, Touch ID, or the device passcode; credentials do not need to be retyped. Ordinary app switches retain the active session and current screen without another sign-in prompt. If you cancel or a connection fails, **Sign in** retries without another automatic prompt loop. If the school session expired, the same authenticated operation signs in again using the saved credentials. Allow Face ID when iOS asks. Cancelling keeps sign-in saved for retry. **Sign in again** and **Sign out** erase the saved session and credentials.

Schoolity keeps an authenticated workspace and its session in memory when sent to the background, then resumes the current screen on return. Explicit sign-out and session rejection still clear the workspace; a full restart still requires protected saved-session restoration. The app covers its main content while inactive. Apple's own authentication prompt does not cause an unlock loop. A rejected saved password returns to school credentials; transient network errors retain the protected entry for retry. Late network responses cannot activate a backgrounded workspace or restore an explicitly forgotten account. Backgrounding during a passcode-free startup check invalidates that attempt; returning restarts it with the saved cookie, so startup cannot remain stranded.

A separate device-only Keychain item stores only discovery flags and expiry, never the username, password, or cookie. Startup can discover saved sign-in without reading a protected secret. Authentication restrictions or temporary Keychain errors do not mean the account is missing and must not delete it. An unreadable entry stays available for retry rather than being silently erased. Old attribute-only metadata is migrated after authentication.

Existing saved sessions are upgraded to require local authentication on the first successful unlock. Devices without a passcode retain the original saved-sign-in behavior; setting up a passcode enables the protected flow on the next reopen. Protected sessions are never retrieved without successful local authentication, even if biometrics become unavailable. Face ID permission denial can fall back to the device passcode or school credentials. Removing the device passcode invalidates protected Keychain entries.

Older installations stored only a session. Enter your school credentials once after updating to enable renewal; a password cannot be recovered from an old session. Devices without a passcode save only the expiring session, never the password.

## Native interface

Course History categories render the district's class details as tables that fit the available screen width with aligned headers and wrapping values, including term, course title/ID, mark, and attempted/completed credits when supplied. Credit strings retain the district's precision. At accessibility text sizes, each course stacks its labeled fields vertically; no horizontal scrolling is used. Category class lists preload with the signed-in workspace and share in-flight requests with expansion. Refreshing Course History invalidates the subject cache, and sign-out cancels and clears it. Empty in-progress groups stay hidden.

Account → Settings contains Grade Colors, Class Names and Icons, and Accent Color. Grade colors support editable minimum-score thresholds, a fallback/ungraded color, saving, and reset. Class names/icons are reusable templates that can be linked to multiple district class titles; deleting a template removes its links. Long-press a course in Grades or Schedule to change its appearance. Accent colors include presets, a custom color picker, and the original adaptive Schoolity default. Settings persist locally in UserDefaults, including user-created names, icons, and their class-title matching links; grades and messages are not saved there. They do not modify district records. The user excluded photo and app-icon customization, so those options are not included. The login palette remains the original Schoolity palette.

The gradebook course rows omit the district-grade caption, and course details omit About estimates. Inactive/background content is covered with a plain system background without Schoolity text. These latest settings and UI changes still require Xcode build, interaction, and visual verification.

The app icon matches the website favicon's white Georgia “S” on #111111. `AppIcon.appiconset` includes a dedicated dark Home Screen appearance with a #000000 background, selected through the catalog's luminosity appearance metadata on supported iOS versions. Both images are opaque 1024×1024 RGB PNGs; iOS supplies the rounded corner mask. Editable sources are in `Brand/AppIcon.svg` and `Brand/AppIconDark.svg`. Home Screen switching still needs simulator/device verification.

Entering the signed-in workspace preloads the profile, schedule, inbox, document listing, student information, attendance, and course history concurrently. Grades continue loading immediately. Each section shares its existing loading/cache guards with tab navigation; failed sections retain their retry states. Sign-out cancels the workspace task, and generation checks reject late responses. File contents still download when selected.

The signed-in interface follows the layout of [Ziggydave1/Pupil](https://github.com/Ziggydave1/Pupil): inset lists, course symbols and stacked grades, large rounded course scores, Assignments/Breakdown selection, expandable assignment details, circular period markers, and icon-led information rows. Schoolity keeps its five tabs, hypothetical tools, inbox, documents, attendance, history, and direct Account barcode. Student Info also links to the ID screen. Login and saved-sign-in UI are unchanged. This refinement is implemented locally; its simulator screenshots and compilation still need validation on a Mac.

The Add hypothetical score button uses a native Liquid Glass button style on iOS 26 when built with a Swift 6.2+ toolchain. Older systems/toolchains and Reduce Transparency use bordered buttons. Data rows, forms, and the student barcode keep standard opaque surfaces. Verify both appearances, Dark Mode, and accessibility text sizes on a Mac before release; the glass branch has not been compiled or rendered on this Windows workspace.

The original Schoolity credential form and saved-sign-in screen are retained, now with a teal accent for primary actions, selected navigation, grade badges and graph marks. Light Mode uses deep teal (#08666E); Dark Mode uses pale teal (#74D8DE), with neutral system backgrounds and labels. The barcode remains black on white. Saved sign-in starts automatically; **Sign in** remains a retry action. Grades open first; Home is removed, leaving Grades, Schedule, Inbox, Documents and Records. Records groups Student Info, Attendance and Course History. Schedule can switch among the district's terms, and Course History exposes graduation progress, year/school filters, course records, and on-demand completed/in-progress subject classes. The remaining compact native inset rows, course symbols and stacked grade lines take Pupil as a visual reference. Account displays the student number and barcode directly, with no extra navigation. Charts and local calculators retain their functions. No Pupil source code, images, branding, SwiftVue, or credential-storage dependencies are bundled.

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

Native reads opt into `{ "normalized": true }` on `/api/portal`, receiving the same decoded display models as the web interface. Raw responses for existing web callers are unchanged. The new `schedule-terms` resource returns the term-aware schedule rather than the legacy flat schedule, so installed clients remain compatible during rollout. Student Info, Attendance and Course History use the normalized `student`, `attendance` and `history` resources; subject classes use `history-subject`. `/api/documents` still checks ownership and authenticates both document and inbox attachment downloads.

On devices with a passcode, the Keychain entry includes the opaque session, its expiration, and saved school credentials, protected with `userPresence` and `WhenPasscodeSetThisDeviceOnly`. Credentials are read only after successful local authentication and used only during sign-in; the in-memory active session contains no password. Non-secret metadata records whether renewal is possible. Without a passcode, `WhenUnlockedThisDeviceOnly` stores only the session. Neither cookie nor credentials are read during client initialization. School records/responses are not saved. Networking uses an ephemeral URLSession without disk cache or cookie jar; redirects are refused. Native requests do not persist passwords on the server; only the web client's opt-in saved sign-in stores them, encrypted, for up to 30 days. Exported files remain where the user saved them; temporary downloads use complete file protection and clear on lock/sign-out.

Internet access and a live Schoolity deployment are required. An expired district session requires another sign-in. Transient read failures retain the current screen and offer Retry. Estimates are independent calculations, not district grades; they never write back to school records. Hypothetical edits last only while the course screen is open.

## Verification

Unit coverage includes points/weighted calculations, excluded and ungraded work, zero and extra credit, category redistribution, target scores, chronology, decoded API models, session expiry, and filename safety. UI tests use original synthetic records in DEBUG builds only; Release has no test/demo entry point. Tests cover login gating, gradebook/chart navigation, hypothetical editing, collapsed messages/senders, schedule, documents, student information, account, and light/dark screenshots. Unit coverage also decodes the term-aware schedule, student information, course history, attendance and subject-detail payloads. At the largest accessibility text size in Dark Mode, screenshots cover Login, the gradebook, course details, Schedule, and the Records screens; the Schedule and Records captures also run at the default size.

Successful compilation and fixture tests do not verify real district credentials, live files, physical-device behavior, or App Store readiness. Real-account compatibility should be checked privately on a signed device build.

Saved-sign-in tests inject a local-authentication provider and server client to check success, cancellation, migration, unavailable authentication, expiry/revocation, logout, and background races without real credentials. DEBUG UI fixtures exercise the saved-sign-in screen and password fallback in light/dark appearances; they do not simulate an actual Face ID scan or prove hardware Keychain authentication. Verify Face ID permission, recognition, cancellation, and passcode fallback on a signed iPhone build.
