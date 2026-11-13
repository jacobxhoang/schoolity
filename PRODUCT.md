# Schoolity

<!-- impeccable:product-schema 1 -->

## Platform

web and native iPhone (SwiftUI, iOS 17+)

## Users

The primary audience is Anoka-Hennepin students, confirmed by the user during initialization. Students use their existing district StudentVUE account to check academic information and plan assignment scores. The interface must work on desktop and mobile browsers.

Parents, teachers, administrators, and students in other districts are not confirmed target audiences.

## Product Purpose

Schoolity brings school information and grade planning into one fast, modern website. Students should be able to understand their current grades, inspect assignments, and estimate how hypothetical scores would affect a course grade without modifying school records.

## Positioning

An independent student dashboard for one district, combining a school portal with grade-planning tools. The user requested original implementation rather than importing code from Student or GradeCompass. Those projects informed the feature brief; Schoolity is not an official continuation of either project or a district-endorsed service.

## Operating Context

- A valid StudentVUE login is required to enter the workspace. There is no anonymous demo entry point.
- The district is fixed to `https://synergyportal.anoka.k12.mn.us` in the interface and server. Do not introduce district selection without a new product decision.
- Core flow: sign in, open the gradebook, inspect a course and its assignments, explore hypothetical scores or target-score planning, and reset changes.
- Additional current sections are overview, schedule, inbox, and documents. Attendance was explicitly removed and must stay absent unless requested again.
- Current local app: `http://127.0.0.1:5180/`. Source application root is this directory; the sibling Student and GradeCompass checkouts are separate projects.
- `npm run dev` launches the SvelteKit development server with hot reload on port 5180. `npm run build` produces a Node server; `npm start` runs that build. The production Node server needs its host, port, and origin configured. Check whether a server already owns the port before starting another.

## Capabilities and Constraints

- Existing stack: SvelteKit, Svelte 5, TypeScript, Vite, and a Node adapter, with original CSS and SVG components.
- Native iPhone source lives in `ios/`, using SwiftUI, Swift Charts, Keychain sessions, and the existing authenticated Schoolity server. GitHub Actions compiles unsigned archives and simulator builds; Apple device/distribution signing is separate. Native views use system navigation, semantic monochrome colors, rounded inset lists, and Dynamic Type. There is no separate iPad interface.
- Native saved sign-in uses Face ID, Touch ID, or device-passcode authentication when a passcode is configured. The user explicitly approved saving school credentials in protected iPhone Keychain storage so Face ID can renew an expired/revoked session. Passwords are never saved on devices without a passcode, or by the server/web client. Sign out and Sign in again remove stored native credentials; a rejected saved password requires manual sign-in. The original credential form and Face ID screen are retained. The first successful protected school sign-in immediately requests local authentication and reads the saved entry back. A separate non-secret Keychain discovery item holds only flags/expiry; authentication or temporary lookup failures must never be treated as a missing account. Saved sign-in automatically starts local authentication on launch and when returning from the background. Cancelling leaves a **Sign in** retry; returning from the system prompt does not restart a scan. Hardware authentication still needs verification on a signed iPhone build.
- Native Account immediately displays only a district-provided student number and an original Core Image Code 128 barcode, preserving leading zeros. No fallback to usernames, GUIDs, or child indexes. Missing IDs have an unavailable/retry state. ID data is not stored persistently; live district ID-field compatibility and scanner acceptance remain unverified.
- Successful iOS builds on `main` publish one unsigned `Schoolity.ipa` asset in GitHub Releases. PR builds cannot publish; repository write permission is limited to the separate release job. Diagnostic artifacts are temporary and opt-in except on test failure.
- Gradebook: reporting-period selection, course details, assignment scores, and calculated grade trends.
- Calculator: points and weighted-category calculations, hypothetical score editing, hypothetical assignments, reset, and target-score estimates.
- School data comes from the district's mobile JSON API through Schoolity's server. Read adapters exist for grades, student identity, schedule, inbox, and document listings.
- Schoolity does not change district records. Inbox is read-only and currently loads up to 50 messages.
- Calendar synchronization, persistent offline school-data caching, and notifications are not implemented. Do not portray them as working features.
- District-specific rounding, dropped scores, standards-based grading, and custom policies may differ from Schoolity's estimates. Preserve the distinction between district-reported and calculated grades.
- The server receives credentials during sign-in but does not save passwords. It holds access tokens in memory locally or in shared Redis storage on Vercel for the district session’s lifetime (up to 30 days) and uses an HTTP-only, SameSite=Lax browser session cookie. Restarting a local server invalidates its in-memory sessions.
- Anonymous HTML shows the login screen. School-data requests require a valid server session. Responses are marked no-store; displayed school data is held in page memory. Only the color-theme preference is saved in local storage.
- Vercel deployment uses shared Upstash Redis sessions and login limits; local development uses in-memory sessions. Deployment settings are in DEPLOYMENT.md.
- The project license is not yet selected. Dependency licenses remain applicable. Do not claim formal clean-room provenance or legal clearance; the implementer previously inspected the reference repositories.

## Brand Commitments

- The user-selected product name is **Schoolity**.
- Preserve the web's black-and-white interface constraint and preference for a compact, straightforward structure similar to Student, while retaining Schoolity's own implementation and branding.
- For native iOS, the user requested Pupil-style layout while explicitly keeping black and white and the original Schoolity unlock screen. The current native request retains the original Schoolity credential form, removes Home, displays student ID directly in Account, and adds restrained color: deep teal actions in Light Mode, pale teal in Dark Mode, with neutral system surfaces. This supersedes native monochrome only; the web palette remains unchanged. Preserve compact native inset lists, course icons and stacked grade lines, and open on Grades with four tabs: Grades, Schedule, Inbox and Documents. Pupil is a visual/behavioral reference only; no source/assets or old API/storage dependencies are imported. Saved-credential renewal follows the user-approved behavior with stronger user-presence Keychain protection.
- Use direct, functional language suited to students completing school tasks. Do not invent endorsements, institutional affiliation, or marketing claims.
- Trademark availability has not been established.

## Evidence on Hand

- Product constraints above come from the user's instructions and the audience confirmation in this conversation.
- Current implementation: `src/routes/+page.svelte`, `src/routes/+page.server.ts`, `src/routes/api/portal/+server.ts`, and `src/lib/`.
- Existing visual implementation is in `src/routes/app.css` and `src/routes/monochrome.css`. It is incumbent evidence, not a reason to redesign during initialization.
- Automated coverage: `tests/grades.test.ts` and `tests/connection.test.ts`. Run `npm test` for calculator, response-mapping, district-validation, session-rejection, and attendance-removal checks. `npm run check` checks Svelte and TypeScript.
- District-specific feature coverage is not comprehensively verified. Do not infer support from a successful build or from calculator tests.
- No testimonials, customer counts, performance benchmarks, pricing, or endorsement assets have been supplied.
- Do not put student credentials, real grades, personal messages, or other student records into product context, screenshots for public distribution, or sample fixtures.

- Inbox attachments are listed inside expanded messages and use an authenticated, parent-message-checked download endpoint. Live district compatibility remains to be verified.
- Document downloads use the authenticated district content API; per-file progress and retries are available. Course search was removed at the user's request.

## Product Principles

1. Put current academic information and the student's next useful action ahead of decoration or promotional content.
2. Keep grade scenarios independent of district records and identify estimates clearly.
3. Require authentication and minimize retention of student information and credentials.
4. Show accurate loading, empty, unsupported-feature, and error states; never fill missing school information with invented data.
5. Preserve the confirmed single-district scope and fast desktop/mobile workflows until the user changes them.

## Open Decisions

- Long-term hosting, distribution, and project license.
- Additional district grading policies and feature support after systematic live verification.
- Product-specific accessibility requirements beyond accessible web implementation have not been specified; do not claim conformance certification.
