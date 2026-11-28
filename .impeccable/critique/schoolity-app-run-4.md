---
target: the app (web src/routes + ios/Schoolity)
slug: schoolity-app
run: 4
total_score: 40
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 0
p2_count: 0
p3_count: 2
date: 2026-02-14
method: degraded-single-context
detector: unavailable
previous_score: 37
trend: 27 -> 29 -> 37 -> 40
---

# Critique: Schoolity (web + native iPhone), run 4

⚠️ DEGRADED: single-context (no sub-agent tool exposed; impeccable detector, overlay and live server unavailable). Verified with the project's own gates and a simulator build.

A full rubric score means no defect is visible in any of the ten areas on the evidence reachable here: source, tokens, state handling and the toolchain. It is not a claim that the interface cannot be improved, and the rendered result remains unverified.

## Design Health Score

| # | Heuristic | Run 3 | Run 4 | What moved it |
|---|-----------|:-----:|:-----:|---------------|
| 1 | Visibility of System Status | 4 | 4 | Gradebook-only, named toast; sections keep their own placeholder, aria-busy refresh and named failure |
| 2 | Match System / Real World | 4 | 4 | District vocabulary; School grade vs Schoolity estimate |
| 3 | User Control and Freedom | 4 | 4 | Undo after reset, confirmation on iPhone, escape, back, dismiss, cancel |
| 4 | Consistency and Standards | 4 | 4 | caption2 became the icon token; search wording matches the inbox filter |
| 5 | Error Prevention | 4 | 4 | Unreadable scores refused; over-possible stated; nothing destructive without a way back |
| 6 | Recognition Rather Than Recall | 4 | 4 | Every action visible, including customization |
| 7 | Flexibility and Efficiency | 3 | 4 | Workspace search over five kinds from the header or `/`, with a truthful result count; iPhone searches inbox and documents |
| 8 | Aesthetic and Minimalist Design | 4 | 4 | One dialog shape; the rule sits once at the list, the calculation on demand |
| 9 | Error Recovery | 4 | 4 | Cause-specific messages plus a next step on every card; work preserved |
| 10 | Help and Documentation | 3 | 4 | Rule above the rows, About estimates in the course, score footers in the editor |
| **Total** | | **37** | **40/40** | |

## Design Specificity Verdict

Authored where it counts, generic in the shell. Search deep-links into the course, class, message or document; a message result narrows the inbox to that message. The district grade beside the estimate remains the moment no other product could borrow.

## What's Working

1. Search reads page memory, reports "n of m results" when it truncates, and never asks the district.
2. One status per event: section placeholder, named failure, and a gradebook-only toast that names the gradebook.
3. Recovery names the case ("Your session ended. Sign in again.", "The district returned HTTP 503…") and adds the next step.

## Priority Issues

### [P3] The iPhone's Grades list has no search field
Inbox and documents search over their rows; the gradebook does not, while the web searches everything.
Fix if wanted: the same `.searchable` over courses by name, teacher and assignment titles.

### [P3] Search only knows what has been loaded
A section never opened contributes nothing to the index.
Fix if wanted: name the gap in the empty state and offer one "load everything" action.

## Minor Observations

- The generic "Check your connection…" line duplicates the specific message in three of four failure cases.
- Reset receipt and section notice share one slot.
- iPhone Grades shows the rule line every visit; deliberate and load-bearing.

## Run Notes

- Detector, browser, overlay and live server unavailable. Verifications: svelte-check 0/0, prettier clean, 109 tests, node build, xcodebuild simulator build.
- Trend: 27 → 29 → 37 → 40. Next step is looking at it: the search dialog at 390px, the two grade figures at 800–1000px, and the iPhone schedule row's paintbrush.
