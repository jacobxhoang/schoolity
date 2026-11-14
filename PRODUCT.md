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
- Core flow: sign in, open the gradebook, inspect a course and its assignments, explore hypothetical scores, and reset changes.
- Additional web sections are schedule, inbox, documents, student info, course history, and attendance. The user explicitly requested attendance again, superseding its earlier removal. Native navigation is Grades, Schedule, Inbox, Documents, and Records; Records groups Student Info, Attendance, and Course History.
- Current local app: `http://127.0.0.1:5180/`. Source application root is this directory; the sibling Student and GradeCompass checkouts are separate projects.
- `npm run dev` launches the SvelteKit development server with hot reload on port 5180. `npm run build` produces a Node server; `npm start` runs that build. The production Node server needs its host, port, and origin configured. Check whether a server already owns the port before starting another.

## Capabilities and Constraints

- Existing stack: SvelteKit, Svelte 5, TypeScript, Vite, and a Node adapter, with original CSS and SVG components.
- Native iPhone source lives in `ios/`, using SwiftUI, Swift Charts, Keychain sessions, a bundled local parser, and a direct HTTPS StudentVUE district connection; the iOS app does not depend on Vercel. GitHub Actions compiles unsigned archives and simulator builds; Apple device/distribution signing is separate. Native views use system navigation, semantic monochrome colors, rounded inset lists, and Dynamic Type. There is no separate iPad interface.
- Native saved sign-in uses Face ID, Touch ID, or device-passcode authentication when a passcode is configured. The user explicitly approved saving school credentials in protected iPhone Keychain storage so Face ID can renew an expired/revoked session. Passwords are never saved on devices without a passcode. The web client can optionally ask the server to keep an encrypted copy of the school login for up to 30 days; the native app does not use that web saved sign-in. Sign out and Sign in again remove stored native credentials; a rejected saved password requires manual sign-in. The original credential form and Face ID screen are retained. The first successful protected school sign-in immediately requests local authentication and reads the saved entry back. A separate non-secret Keychain discovery item holds only flags/expiry; authentication or temporary lookup failures must never be treated as a missing account. Saved sign-in starts local authentication on a full app launch or after session expiry; ordinary background/foreground app switches keep the authenticated workspace and current screen in memory without another sign-in. App switching keeps the current screen visible. Cancelling leaves a **Sign in** retry; returning from the system prompt does not restart a scan. Hardware authentication still needs verification on a signed iPhone build.
- Native Account immediately displays only a district-provided student number and an original Core Image Code 128 barcode, preserving leading zeros. No fallback to usernames, GUIDs, or child indexes. Missing IDs have an unavailable/retry state. ID data is not stored persistently; live district ID-field compatibility and scanner acceptance remain unverified.
- Successful iOS builds on `main` publish one unsigned `Schoolity.ipa` asset in GitHub Releases. PR builds cannot publish; repository write permission is limited to the separate release job. Diagnostic artifacts are temporary and opt-in except on test failure.
- Gradebook: reporting-period selection, course details, assignment scores, and calculated grade trends.
- Calculator: points and weighted-category calculations, hypothetical score editing, hypothetical assignments, and reset.
- School data comes from the district's mobile JSON API through Schoolity's server. Read adapters exist for grades, student identity, schedule, inbox, document listings, attendance, course history, and student information. Course history subject details load on demand through the authenticated server session.
- The web and native schedules both support switching among district schedule terms. Native scheduling reads an opt-in `schedule-terms` response so installed clients that still consume the older flat schedule shape continue to work.
- Schoolity does not change district records. Inbox is read-only and currently loads up to 50 messages.
- A live calendar subscription feed, two-way calendar sync, and persistent offline school-data caching are not implemented. Native graded-assignment notifications are opt-in local alerts with silent initial baselines, foreground polling, and opportunistic iOS background refresh. They require an active in-memory district session; they are not real-time server push.
- District-specific rounding, dropped scores, standards-based grading, and custom policies may differ from Schoolity's estimates. Preserve the distinction between district-reported and calculated grades.
- The server receives credentials during sign-in and, only when the student selects the web **Keep me signed in** option (off by default), stores them encrypted with AES-256-GCM in shared storage for up to 30 days. Signing out deletes the saved copy and every linked session. It holds access tokens in memory locally or in shared Redis storage on Vercel for the district session’s lifetime (up to 30 days) and uses an HTTP-only, SameSite=Lax browser session cookie. Restarting a local server invalidates its in-memory sessions.
- Anonymous HTML shows the login screen. School-data requests require a valid server session. Responses are marked no-store; displayed school data is held in page memory. Only the color-theme preference is saved in local storage.
- Vercel deployment uses shared Upstash Redis sessions, saved sign-ins, and login limits; local development uses in-memory sessions. Deployment settings are in DEPLOYMENT.md.
- The project license is not yet selected. Dependency licenses remain applicable. Do not claim formal clean-room provenance or legal clearance; the implementer previously inspected the reference repositories.

## Brand Commitments

- The user-selected product name is **Schoolity**.
- Preserve the web's black-and-white interface constraint and preference for a compact, straightforward structure similar to Student, while retaining Schoolity's own implementation and branding.
- For native iOS, the user requested Pupil-style layout while explicitly keeping black and white and the original Schoolity unlock screen. The current native request retains the original Schoolity credential form, removes Home, displays student ID directly in Account, and adds restrained color: deep teal actions in Light Mode, pale teal in Dark Mode, with neutral system surfaces. This supersedes native monochrome only; the web palette remains unchanged. Preserve compact native inset lists, course icons and stacked grade lines, and open on Grades with five tabs: Grades, Schedule, Inbox, Records and Account. Records groups Student Info, Attendance, Course History and Documents. Account is a tab, not a toolbar sheet, and holds the student ID, Settings and Sign out. Pupil is a visual/behavioral reference only; no source/assets or old API/storage dependencies are imported. Saved-credential renewal follows the user-approved behavior with stronger user-presence Keychain protection.
- Use direct, functional language suited to students completing school tasks. Do not invent endorsements, institutional affiliation, or marketing claims.
- Trademark availability has not been established.

## Evidence on Hand

- Product constraints above come from the user's instructions and the audience confirmation in this conversation.
- Current implementation: `src/routes/+page.svelte`, `src/routes/+page.server.ts`, `src/routes/api/portal/+server.ts`, and `src/lib/`.
- Existing visual implementation is in `src/routes/tokens.css` (palette, type scale, radii), `src/routes/app.css` (shared primitives), `src/routes/login.css` (signed-out surface) and `src/routes/workspace.css` (signed-in surface). It is incumbent evidence, not a reason to redesign during initialization.
- Automated coverage is in `tests/*.test.ts`. Run `npm test` for calculator, response-mapping, district-validation, session-rejection, saved-sign-in recovery, and attendance-removal checks. `npm run check` checks Svelte and TypeScript.
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

## Student record expansion

Native Course History category details use aligned district columns sized to fit the screen, with vertically wrapping values and a stacked-field layout at accessibility text sizes, following the user's table reference. Workspace preloading includes subject class lists; cache/in-flight sharing avoids duplicate expansion requests. History refresh and sign-out invalidate the subject cache with separate history/session generation checks. Empty in-progress groups remain hidden.

Native customization is available in Account → Settings: saved grade colors with configurable score thresholds/fallback/reset, reusable class name/icon templates and links shared by Grades/Schedule, and preset/custom accent colors. Long-pressing a course opens class appearance selection. User-selected colors supersede the default native palette on signed-in screens; login keeps its original palette. User-created preferences and class-title links persist locally in UserDefaults, independently from in-memory district records. The user explicitly excluded ID-photo and app-icon customization. Gradebook rows no longer show the district-grade caption; course details omit About estimates; the inactive-scene privacy cover is a plain system background without branding.

Native signed-in workspace entry starts concurrent profile, schedule, inbox, document-list, student-info, attendance, and course-history loads. The existing per-resource loading and cache guards prevent duplicate requests when opening tabs; retryable failures remain local to each section. The workspace task owns the structured child tasks, and session-generation checks prevent late responses restoring cleared data. Actual files download on selection.

Portal and download endpoints share bounded same-origin JSON parsing with byte-based limits, including bodies without Content-Length. Workspace requests and subject preloads guard against stale session generations; tab navigation surfaces failures from an already-running background preload. Local storage capacity limits new keys without preventing existing entries from being updated.

The latest native visual refinement follows Ziggydave1/Pupil closely across signed-in screens: compact inset lists, course icons above stacked grade lines, rounded course-grade typography with linear progress, an Assignments/Breakdown selector, expandable assignments with score indicators, trailing circular schedule periods, and icon-led student/contact rows. Student Info links to the district ID, while Account still shows the barcode directly. The five Schoolity tabs and all existing features remain; the credential and saved-sign-in screens are unchanged. This supersedes the earlier inset-grouped/side-by-side course-row treatment. Grade refresh keeps existing courses visible with a toolbar progress indicator. Gradebook content compares only gradebook/loading/error inputs so unrelated store publications skip that subtree; the iOS gradebook shows only the term picker and course list, with Overview and Recent assignments removed. Grade-history prefixes use incremental category totals. The latest visual changes require Xcode/device validation.

The web Student Info page displays district-provided identity, school and contact fields. Course History reads district web-page JSON through the authenticated server session and provides year/school filters, marks and credits. Attendance reads the district mobile Attendance resource and preserves per-period status and reasons. Unknown formats produce retryable errors; absent data is not replaced with invented values or zero totals. All new records remain in page memory and clear on sign-out. District web cookies are kept server-side for course history; existing sessions may require sign-in again. These new adapters need private live-account verification. The calculator label is Hypothetical on web and iPhone.

Course History leads with StudentVUE-style subject-area graduation progress bars, showing completed/in-progress credit segments plus district-reported required, completed, in-progress, and remaining credits. Course records and their filters remain in an expandable section below. Graduation requirements come from the authenticated district web page; never infer graduation requirements from marks or fill missing credit totals with zero.

Subject-area labels expand inline to show district-associated Completed and In progress class lists. Details load on demand through GetCourseHistoryDetails with the requirement identifier, after verifying that identifier against the authenticated student's graduation requirements. Finalized marks identify completed courses (including F/P); blank marks identify pending courses, matching StudentVUE's grouping. Refresh clears cached subject details. Preserve loading, retry, empty states, keyboard controls, and mobile reflow.

Student Info supplements mobile identity data with all readable sections from the authenticated district Student Info page: emergency contacts, physician and dentist details, lockers, transportation, other data, and activity screening. Preserve empty labeled fields as Not provided, leading zeros, and multiline values such as addresses. Display district HTML as safe text with line breaks. Keep web cookies server-side and show a partial-data notice if the supplemental page cannot load. Fictional fixtures cover parsing and responsive display; authenticated end-to-end retrieval still needs live verification.

The iOS target-score feature has been removed. Course details retain adding/editing hypothetical scores and resetting changes.
