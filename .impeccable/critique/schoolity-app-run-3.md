---
target: the app (web src/routes + ios/Schoolity)
slug: schoolity-app
run: 3
total_score: 37
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 0
p2_count: 2
p3_count: 2
date: 2026-02-14
method: degraded-single-context
detector: unavailable
previous_score: 29
trend: 27 -> 29 -> 37
---

# Critique: Schoolity (web + native iPhone), run 3

⚠️ DEGRADED: single-context (no sub-agent tool exposed; impeccable detector, overlay and live server unavailable). Verified with the project's own gates and a simulator build.

## Design Health Score

| # | Heuristic | Run 2 | Run 3 | What moved it |
|---|-----------|:-----:|:-----:|---------------|
| 1 | Visibility of System Status | 3 | 4 | Section placeholders while any load is in flight, disabled + aria-busy Refresh, background failures surfaced by name |
| 2 | Match System / Real World | 3 | 4 | "Unweighted" removed; rows named as estimates; district figure labelled School grade |
| 3 | User Control and Freedom | 3 | 4 | Undo after reset on the web; confirmation on iPhone; escape, back, dismiss, cancel everywhere |
| 4 | Consistency and Standards | 3 | 4 | Mirrored IA, one iOS dropdown, one iOS type vocabulary, one hover treatment |
| 5 | Error Prevention | 3 | 4 | Unreadable scores refused; over-possible stated beside the figure |
| 6 | Recognition Rather Than Recall | 3 | 4 | Visible customization entries on both lists |
| 7 | Flexibility and Efficiency | 2 | 3 | Inbox filter over the loaded 50 |
| 8 | Aesthetic and Minimalist Design | 4 | 4 | Unchanged |
| 9 | Error Recovery | 3 | 3 | Section-named failures with Retry; message text still the server's |
| 10 | Help and Documentation | 2 | 3 | About estimates on both surfaces, plus score-editor footers |
| **Total** | | **29** | **37/40** | **Excellent** (bottom of band) |

## Design Specificity Verdict

Authored where it counts, generic in the shell. The district grade beside the Schoolity estimate now appears on both surfaces, labelled on both sides, with an explanation one tap away. The shell stays a standard dashboard, which is correct for an Operate surface.

## What's Working

1. The grade pair never lies: School grade reported by the district, estimate moving only with scenarios.
2. Three unmistakable section states: loading placeholders, named failure with Retry, honest empty.
3. One vocabulary across surfaces: palette, scale, type roles, dropdown pattern, navigation shape.

## Priority Issues

### [P2] No search outside the inbox
Inbox filters over its 50 messages; nothing searches assignments, courses, documents or records.
Fix: one workspace search over page memory, reachable from the header, deep-linking into a course or message. Command: `$impeccable harden`.

### [P2] Help exists only where the explained thing is
About estimates sits in the course header; a student who does not know what an estimate is will not open it.
Fix: one first-run note above the course list that states the estimate rule once. Command: `$impeccable onboard`.

### [P3] The global "Updating…" toast duplicates its section
Two indicators for one state, and the toast names no section.
Fix: keep it for same-screen refreshes or name the section. Command: `$impeccable quieter`.

### [P3] caption2 is the last hand-named font on iPhone
`.font(.caption2)` covers both chevrons and the version line.
Fix: an icon scale for chevrons, `meta` for the version line. Command: `$impeccable polish`.

## Persona Red Flags

- **Alex**: no keyboard path to Refresh, no cross-section search.
- **Sam**: dropdowns are fully operable; the filter's "n of 50" count is visual only.
- **Casey**: web Refresh sits at the top of the page, outside the thumb zone.

## Minor Observations

- Reset receipt and section notice share one slot.
- Course rows show the estimate; one line above the list says so.
- `SchoolityStyle` is a single constant now.
- Dense trends label only their latest point; the screen-reader list keeps all.

## Questions to Consider

- Should cross-section search exist before live district verification?
- Is one first-run sentence enough for the estimate rule?
- If the section owns its status, what is the toast for?

## Run Notes

- Detector, browser, overlay and live server unavailable. Verifications: svelte-check 0/0, prettier clean, 109 tests, node build, xcodebuild simulator build.
- Scoring is code-evidenced; the rendered interface is unverified. First visual checks: the grade pair at 800–1000px and the note above the course list.
