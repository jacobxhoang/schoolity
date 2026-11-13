# Schoolity

An independently implemented student dashboard for Anoka-Hennepin. Attendance has been removed. A valid StudentVUE login is required to access the workspace. There is no demo entry point.

The native SwiftUI iPhone app is in [`ios/`](ios/README.md). The **iOS** GitHub Actions workflow compiles the app on macOS, runs simulator tests, and publishes a single unsigned IPA to GitHub Releases after successful builds on `main`. See the [iPhone build instructions](ios/README.md) for Xcode, signing, and installation requirements.

## Run locally

Use Node.js 22.18 or newer within the 22.x release line, matching the Vercel runtime.

```
npm install
npm run dev
```

Open http://127.0.0.1:5180. Sign in with your StudentVUE username and password. The district is fixed to https://synergyportal.anoka.k12.mn.us on both the interface and the server; other district addresses are rejected.

```
npm run check
npm test
npm run build
npm start
```

For the production Node server set HOST=127.0.0.1, PORT=5180, and ORIGIN=http://127.0.0.1:5180 locally. Use HTTPS and the correct ORIGIN for deployment. Local sessions live in server memory. On Vercel, sessions and login limits use shared Upstash Redis storage. See [DEPLOYMENT.md](DEPLOYMENT.md) for project settings, required environment variables, and verification.

## Features and privacy

The workspace includes a gradebook, original weighted/points-based calculations, hypothetical assignments, a target-score calculator, and read adapters for schedule, inbox, and document listings. Unauthenticated HTML renders the login screen; every school-data request checks the session cookie. Signing out clears the displayed school data.

Course detail keeps the district grade beside the Schoolity estimate, with a visible grade-history graph above the what-if controls and assignments. Calculation details stay under “About estimates.” What-if mode announces score changes, supports removing individual hypothetical assignments, and explains unavailable target calculations. Course navigation supports browser Back/Forward; refresh failures retain the current workspace and offer Retry. Login includes password reveal. Mobile navigation supports keyboard focus trapping, Escape, and focus restoration.

The web client and server do not save passwords by default. When a student selects **Keep me signed in**, the server stores an encrypted copy of the school login for up to 30 days so an expired session can renew; signing out deletes it and every linked session. Credentials are never stored in browser local storage. The native iPhone app can save credentials in a device-only Keychain entry protected by Face ID/Touch ID or passcode, so an expired session can sign in again after local authentication; see [iPhone privacy and sign-in behavior](ios/README.md). Access tokens are stored for the district session’s lifetime (up to 30 days) in server memory locally, or in a shared session store on Vercel. The browser receives an HTTP-only, SameSite=Lax cookie. Page and API responses are marked no-store. The color theme is the only local-storage preference. A hosting operator can access credentials and school information while forwarding requests, and can decrypt saved sign-ins if they control the encryption key.

## Verification and limits

Calculator, data mapping, connection validation, fixed district configuration, and removal of the attendance resource have automated coverage. Real Anoka account login still requires verification. District grading policies may differ from estimates. Inbox is read-only and limited to 50 messages. Authenticated document downloads are implemented with account-membership checks and strict file decoding; live district download compatibility still needs verification. Inbox attachments can be downloaded from expanded messages using the authenticated mail API; live district compatibility still needs verification. Calendar sync and persistent offline caching are not implemented. No actual student credentials were used during development tests.

## Original implementation

No source code, assets, or branding is imported from Student or GradeCompass. This is not represented as a formal clean-room implementation: the implementer previously inspected those projects. No project license has been selected. Third-party dependencies retain their own licenses. Schoolity is a user-selected working name; trademark availability has not been investigated.

## Impeccable project context

`PRODUCT.md` records the confirmed audience, workflows, scope, and constraints. `.impeccable/config.json` records the user's image-mockup-first preference for future landing and showcase surfaces; app screens remain code-first. `.impeccable/live/config.json` identifies the SvelteKit shell for future local development sessions. Live mode is not currently started or injected into the production app.

Keep durable design context in version control: `PRODUCT.md`, `DESIGN.md` when created, `.impeccable/config.json`, `.impeccable/surfaces/`, `.impeccable/design.json`, `.impeccable/live/config.json`, and `.impeccable/critique/ignore.md` when created. Do not blanket-ignore `.impeccable/`. Runtime questions, mocks, review captures, and critique snapshots manage their own ignores; `.impeccable/config.local.json` stays machine-local.
