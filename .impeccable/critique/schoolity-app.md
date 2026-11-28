---
target: the app (web src/routes + ios/Schoolity)
slug: schoolity-app
run: 1
total_score: 27
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 3
date: 2026-02-14
method: degraded-single-context
detector: unavailable
---

# Critique: Schoolity (web + native iPhone)

⚠️ DEGRADED: single-context (no sub-agent tool exposed; impeccable launcher, detector and live overlay unavailable — no shell or dev server on this device).

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Theme toggle shows a static sun icon in both themes; per-section iOS refreshes announce nothing |
| 2 | Match System / Real World | 4 | District vocabulary used consistently on both platforms |
| 3 | User Control and Freedom | 3 | A single hypothetical edit cannot be undone, only all of it |
| 4 | Consistency and Standards | 2 | Two palettes named the same; sign-in dialog escapes its palette; three "choose one" controls on iOS |
| 5 | Error Prevention | 2 | Web score inputs silently coerce non-numeric input to 0 |
| 6 | Recognition Rather Than Recall | 3 | iOS "Customize class" is long-press-only |
| 7 | Flexibility and Efficiency | 2 | No keyboard shortcuts, no search, no bulk action |
| 8 | Aesthetic and Minimalist Design | 3 | Sign-in surface carries a mock gradebook and a decorative gradient |
| 9 | Error Recovery | 3 | Plain-language failures with Retry/Dismiss; messages lean generic |
| 10 | Help and Documentation | 2 | Good privacy docs; no in-place explanation of estimates on iOS |
| **Total** | | **27/40** | **Acceptable** |

## Design Specificity Verdict

Generic-precision, not authored. Coherent system, interchangeable composition: swap the labels and the layout fits any admin dashboard. Product-specific moments are the School grade vs Schoolity estimate pair, the term line, and the graduation credit bars.

## Overall Impression

Careful, disciplined work with a complete state vocabulary. What holds it back is drift: a re-declared palette, a dialog outside its surface's scope, a dozen one-off type sizes, and three patterns for the same iOS dropdown.

## What's Working

1. The honesty of the estimate — district grade and calculation side by side, local edits clearly local.
2. A complete, quiet state vocabulary (skeletons reserving layout, per-section retry, dashed empty cards, "Not graded" / "Extra credit").
3. Native platform respect — Dynamic Type stacking, `List` layout deferral, Reduce Motion fading instead of removing feedback.

## Priority Issues

### [P1] Sign-in Privacy dialog escapes the sign-in palette
`.login-page` scopes a light-only palette (login.css 4–20) but the Privacy modal renders outside that `<main>` (+page.svelte 1695) and reads root tokens; `.dark` applies to the shell even when signed out (+page.svelte 900), so the dialog opens dark over a light page and its Done button gets `.dark .primary { background:#f2f2f2 }` (app.css 23–26). Account has the same gap.
Fix: scope the login palette to the state, not the `<main>`; delete `.dark .primary` literals. Command: `$impeccable polish`.

### [P1] "Choose one from a list" works three ways on iPhone
Reporting period is a native `Menu` inside a bordered card (GradebookViews.swift 127), schedule term a native `Menu` (ScheduleView.swift 78), Course History uses the popover `SchoolitySelectField` (InterfaceStyle.swift 445), course detail a segmented `Picker`. `SchoolityMenu`'s own doc comment explains why the native menu is wrong inside a card row (row resize, clipped corners).
Fix: one dropdown pattern app-wide. Command: `$impeccable audit`.

### [P1] Non-numeric hypothetical score becomes 0 on web
`editAssignment` does `Math.max(0, Number(value) || 0)` (+page.svelte 517–539): typing a letter writes 0, recalculates, and the live region announces a new percentage. iOS validates and disables Save for the same action (GradebookViews.swift 619–627).
Fix: keep raw input, pause the estimate on unparseable values, mirror native guards. Command: `$impeccable harden`.

### [P2] Declared type floor crossed
tokens.css says nothing renders below `--t-mini` (13px) and DESIGN.md asks for 13px metadata; shipped at 11.5px (login.css 422) and 12.5px (app.css 39, `.primary.small` used by Retry, Add hypothetical, Download). ~19 hand-written sizes against an 8-step scale.
Fix: raise floors, map one-offs onto the scale. Command: `$impeccable typeset`.

### [P2] Two palettes, same names, drifting
`.login-page` re-declares eight palette variables (login.css 5–13) despite tokens.css's "never restate the palette" header, and values differ (#f3f3f3 vs #f7f7f8, #e4e4e4 vs #e6e6e8). Hard-coded hexes in app.css (`#262626`, `#f2f2f2`, `#111111`), login.css (`#9a9a9a`), workspace.css (`#ffffff1f`).
Fix: one palette in tokens with a surface-scoped login set. Command: `$impeccable document`.

## Cognitive Load

2 failures: minimal choices (Course History and iOS Settings stack many controls per screen); one thing at a time (web hypothetical editing changes the estimate, table, and announcement together).

## Persona Red Flags

- **Alex (Power User)**: no keyboard refresh shortcut; term picker not reachable without tabbing the header; inbox capped at 50 with no search; iOS "Customize class" long-press-only.
- **Sam (Accessibility-Dependent)**: Account dialog does not `inert` the page behind it (+page.svelte 965); Privacy dialog's `<summary>` missing from the focus trap selector (+page.svelte 756); 11.5px/12.5px labels below the readable floor.
- **Casey (Distracted Mobile User)**: per-section Refresh and the theme toggle sit at the top of the page, out of thumb reach; web re-runs `load()` on back/forward-cache restore, turning a glance into a network wait.

## Minor Observations

- Stray `.course-card:hover { border-color: var(--accent) }` at workspace.css 1668 overrides the earlier hover and diverges from `.document-card:hover`; near-white border in Dark Mode.
- Theme toggle always renders `sun`, no visual state change.
- Sign-in rail shows plausible invented figures ("Algebra II", "91.2%", "37 / 40") labelled "Example view".
- Rail uses a radial gradient (login.css 323) where the direction asks for no decorative effects.
- iOS fires `.sensoryFeedback(.success)` on every successful refresh, including automatic ones.
- `SchoolityStyle`'s comment says sign-in keeps the teal accent; both login screens tint with `SchoolityLoginPalette.ink`.
- Student Info empty branch offers a manual "Load Student Info" button although `preloadWorkspace()` already loads it.

## Questions to Consider

- If the sidebar disappeared, what in the gradebook would still say "this is a school"?
- Should the sign-in preview show the estimate comparison instead of a mock gradebook?
- What would one dropdown pattern and one type scale cost, given both already exist?
- Does the workspace need a third surface level, or should nested cards become separators?

## Run Notes

- Single inline context; banner declared. Detector, browser evidence, overlay injection and live server all unavailable (no shell, no dev server, signed-in workspace behind a real district login).
- Snapshot written by hand; `impeccable critique-storage` could not run, so no trend and no fingerprint.


## Status after the first polish pass

- **P1 theme consistency: fixed.** The sign-in palette lives on the signed-out shell, `.dark` no longer applies while signed out, and the hard-coded `.dark .primary` values became `--ink-hover`, `--ink-press` and `--on-ink`.
- **P1 iOS dropdowns: fixed.** The reporting period and the schedule term open `SchoolityMenu`, like every other list of options.
- **P1 hypothetical input: fixed.** The web keeps the raw value, accepts only non-negative numbers, and shows an inline hint instead of writing 0. Fields are text with a decimal keypad, matching the native guards.
- **P2 type floor: fixed.** No web size renders below 13px; page titles, large figures and brand marks read from `--t-page`, `--t-page-sm`, `--t-stat-lg`, `--t-stat`, `--t-stat-sm` and `--t-mark`.
- **P2 palette drift: fixed.** `login.css` holds only the signed-out values, `.dark` states only what changes, and the scattered literals became tokens.
- **Minor observations: fixed.** The Account dialog is inert-isolated, the Privacy summary is inside the focus trap, the theme toggle shows a moon in Dark Mode, the stray course-card hover override is gone, the rail gradient is flat, the sign-in preview became a plain feature list, and the iOS success haptic became a selection haptic on term change.
- **Unchanged:** the web Student Info empty state still offers a manual load; it is the recovery path when a background preload fails.
