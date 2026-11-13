# Schoolity

<!-- impeccable:product-schema 1 -->

## Platform

web

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
- Gradebook: reporting-period selection, course details, assignment scores, and calculated grade trends.
- Calculator: points and weighted-category calculations, hypothetical score editing, hypothetical assignments, reset, and target-score estimates.
- School data comes from the district's mobile JSON API through Schoolity's server. Read adapters exist for grades, student identity, schedule, inbox, and document listings.
- Schoolity does not change district records. Inbox is read-only and currently loads up to 50 messages.
- Message attachments, calendar synchronization, persistent offline school-data caching, and notifications are not implemented. Do not portray them as working features.
- District-specific rounding, dropped scores, standards-based grading, and custom policies may differ from Schoolity's estimates. Preserve the distinction between district-reported and calculated grades.
- The server receives credentials during sign-in but does not save passwords. It holds access tokens in memory for at most 30 minutes and uses an HTTP-only, same-site browser session cookie. Restarting the server invalidates sessions.
- Anonymous HTML shows the login screen. School-data requests require a valid server session. Responses are marked no-store; displayed school data is held in page memory. Only the color-theme preference is saved in local storage.
- Current session storage supports one server instance. Distributed hosting needs a secure shared session mechanism. Public deployment and the long-term hosting model are undecided.
- The project license is not yet selected. Dependency licenses remain applicable. Do not claim formal clean-room provenance or legal clearance; the implementer previously inspected the reference repositories.

## Brand Commitments

- The user-selected product name is **Schoolity**.
- Preserve the user's explicit black-and-white interface constraint and preference for a compact, straightforward structure similar to Student, while retaining Schoolity's own implementation and branding.
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
