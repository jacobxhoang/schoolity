---
target: the app (web src/routes + ios/Schoolity)
slug: schoolity-app
run: 2
total_score: 29
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 1
p2_count: 3
p3_count: 1
date: 2026-02-14
method: degraded-single-context
detector: unavailable
previous_score: 27
---

# Critique: Schoolity (web + native iPhone), run 2

⚠️ DEGRADED: single-context (no sub-agent tool exposed; impeccable detector, overlay and live server unavailable). Code verified this session by the project's own checks and a simulator build.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | A preloaded section can still flash its empty card before content arrives |
| 2 | Match System / Real World | 3 | The summary figure is called "Unweighted", which reads as GPA language |
| 3 | User Control and Freedom | 3 | Reset changes is all-or-nothing; one hypothetical edit cannot be undone |
| 4 | Consistency and Standards | 3 | Documents lives in two places; iOS type roles are set two ways |
| 5 | Error Prevention | 3 | Unreadable scores are refused; earned above possible is accepted silently |
| 6 | Recognition Rather Than Recall | 3 | "Customize class" is long-press only |
| 7 | Flexibility and Efficiency | 2 | No search or filter in a 50-message inbox; no refresh shortcut |
| 8 | Aesthetic and Minimalist Design | 4 | One palette, one card, one scale, no gradients, no invented figures |
| 9 | Error Recovery | 3 | Local failures with Retry and Dismiss; some messages stay generic |
| 10 | Help and Documentation | 2 | No in-place explanation of estimates on iPhone |
| **Total** | | **29/40** | **Good** (27 → 29) |

## Design Specificity Verdict

Generic-precision with fewer seams. The palette, scale, dropdown pattern and dialog isolation are now composed; the composition itself is still interchangeable between products. Authored moments: School grade vs Schoolity estimate, the term line, the graduation credit bars.

## What's Working

1. The sign-in surface is honest: no mock figures, a light palette that covers its dialogs, a flat rail.
2. The hypothetical field cannot lie: invalid input stays visible with an inline hint and never moves the estimate.
3. iPhone has one dropdown: reporting period, schedule term and Course History filters share one floating list.

## Priority Issues

### [P1] The headline number is called "Unweighted"
Web says "Course average / Unweighted"; iPhone says "Course average / X courses". The figure is the mean of course percentages, and "unweighted" is GPA weighting language in this district's vocabulary.
Fix: name it plainly and identically on both surfaces. Command: `$impeccable clarify`.

### [P2] Documents belongs in two different places
iPhone puts Documents under Records (SchoolityApp.swift 80); the web puts it beside Inbox in an unlabelled group and labels only the middle Records group (+page.svelte 71–90).
Fix: mirror the iPhone grouping on the web, and label all groups or none. Command: `$impeccable layout`.

### [P2] The inbox is the one list that cannot be narrowed
Latest 50 messages, no search, filter or sender grouping, while Course History has school and year filters.
Fix: one inline filter over the loaded list matching subject, sender and date. Command: `$impeccable harden`.

### [P2] iPhone sets the same type roles two ways
`.font(.headline)` in ~10 places and `.font(.caption)` in ~18 compete with `SchoolityText.cardTitle`/`.meta`; `SchoolityText.pageTitle` is declared and never used (InterfaceStyle.swift 82).
Fix: delete the dead token, add one caption-scale token, route raw fonts through `SchoolityText`. Command: `$impeccable typeset`.

### [P3] One control still hovers to the ink border
`.select-trigger:hover { border-color: var(--accent) }` (SelectMenu.svelte 183) is the last accent-as-hover border; every other control uses `--line-strong`.
Fix: use `var(--line-strong)`. Command: `$impeccable polish`.

## Persona Red Flags

- **Alex**: no refresh shortcut; unsearchable inbox; reset-all is the only way to undo one edit.
- **Sam**: the web dropdown is compliant (arrows, Home/End, typeahead, Escape, focus return); the remaining cost is endurance over 50 collapsed messages.
- **Casey**: refresh sits at the top of each page on the web, outside the thumb zone, while iPhone has pull-to-refresh.

## Minor Observations

- Two unlabelled nav groups around one labelled group imply a hierarchy that is not there.
- `.stat-card > span` and `.course-card-bottom` keep flex properties for a single child.
- `SchoolityStyle.muted` duplicates `SchoolityPalette.muted`.
- The same summary figure carries different secondary text on web and iPhone.
- Past six assignments the trend labels only its latest point; the screen-reader list keeps every value.

## Questions to Consider

- Should the web sidebar become the iPhone's five tabs, or is the flatter web list deliberate?
- Would keeping "Unweighted" with one line of explanation serve students better than renaming it?
- What would the inbox look like loading 20 messages and filtering as you type?
- Could the sign-in rail show the estimate comparison in words rather than a mock?

## Run Notes

- Detector, browser, overlay and live server unavailable. Verifications run on the build Mac: svelte-check 0/0, prettier clean, 109 tests, node build, xcodebuild simulator build.
- Snapshot written by hand; trend read skipped.


## Status after the second build pass

- **P1 summary label: fixed.** The web summary reads "Course average" beside "Courses"; "Unweighted" is gone, the iPhone card already used the same words, and the unused `.stat-card small` styles were removed.
- **P2 Documents IA: fixed.** Web navigation mirrors the iPhone tabs: Gradebook and Schedule, then Records (Student Info, Attendance, Course History, Documents), then Messages (Inbox). The rule is recorded in DESIGN.md.
- **P2 inbox narrowing: fixed.** One filter row over the loaded list matches subject, sender, date and body, shows "n of 50", offers Clear, and has its own "No messages match" empty state. It resets when leaving the section and on sign-out.
- **P2 iOS type tokens: fixed.** `SchoolityText` is the only font vocabulary: `caption` added, unused `pageTitle` deleted, and every raw `.font(.headline)`, `.font(.caption…)` and `.font(.footnote…)` now reads a role token with the same value.
- **P3 hover border: fixed.** The select trigger hovers to `--line-strong` like every other control; the last `--accent`-as-hover border is gone.
- **P3 hidden customization: fixed.** The course screen carries a Customize action in its toolbar and each schedule row shows a paintbrush control; press and hold still works.
- **Also cleaned:** the single-child flex containers on the web summary and course card.
- **Unchanged:** `.font(.caption2)` remains for chevrons and the version line, which are icon and footnote-scale roles rather than text sizes.
