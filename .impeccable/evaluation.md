# Schoolity (web + iPhone): evaluation

Reviewed with `evaluate` (heuristics, cognitive walkthrough, anti-patterns), `include` (accessibility), `fortify` (states), `swiftui-pro` (SwiftUI code) and `mobile-ios-design` (HIG), on top of the four `impeccable` critique runs already on record.

What could not be checked: the app rendered. No browser can reach the local dev server from here, the signed-in workspace needs a real StudentVUE account, and the simulator's screen cannot be read back. Everything below comes from source, the rendered signed-out HTML, and the project's own toolchain (svelte-check, Prettier, 109 tests, node build, simulator build).

## Anti-Pattern Verdict

Clean. No prechecked consent (Keep me signed in is off by default), no fabricated urgency or scarcity, no infinite scroll or streak mechanics, notifications requested only when the student turns them on, and no confirmation-shaming anywhere. The one debated pattern — a dismissible "About estimates" explanation — informs rather than nags.

No critical findings.

## Priority Issues

### Major

**A failed refresh on the gradebook, schedule and record screens lands below the content**
- **What happens:** the failure card is the last row of the list in the gradebook (`GradebookViews.swift:95-98`), schedule (`ScheduleView.swift:52-57`) and each record screen (`RecordViews.swift:170-175`, `429`, `587`), while Inbox and Documents put it first (`ResourceViews.swift:29-37`).
- **Why it matters:** after a failed pull-to-refresh the student is looking at the top of the list, above the explanation, so yesterday's grades look like today's.
- **Breaks:** visibility of system status; consistency and standards.
- **Change:** put the failure above the section's content everywhere, as Inbox already does.

**Leaving a course silently discards hypothetical edits**
- **What happens:** edits live in `CourseDetailView`'s `@State course` and disappear when the screen closes; no prompt and no undo on the way out. The behaviour is documented in `PRODUCT.md`, but nothing on screen warns.
- **Why it matters:** a student who plans a scenario, swipes back to check an assignment, and returns has to rebuild it.
- **Breaks:** user control and freedom (no exit from the loss); error prevention.
- **Change:** confirm before leaving with changes, or keep the edit for that course while the session lasts.

**One store drives every screen**
- **What happens:** `AppStore` publishes 30+ properties (`AppStore.swift:6-31`) and every view observes the whole object through `@EnvironmentObject`. Only the gradebook is shielded, by `.equatable()`; `Account`, `Records`, `Schedule` and the resource lists re-evaluate on any publish, including a mail or document refresh.
- **Why it matters:** work happens on screens the student is not looking at, which shows up as scroll jank on the screen they are.
- **Breaks:** flexibility and efficiency of use (responsiveness).
- **Change:** split per-feature observable models, or move to `@Observable` so a change notifies only the views that read it.

### Minor

**The `/` shortcut cannot be remapped or turned off**
- **What happens:** a global keydown handler opens search on `/` whenever focus is not in a field (`+page.svelte`, `svelte:window` handler).
- **Why it matters:** voice-control and speech-input users who speak a phrase containing a slash open it by accident, and there is no way to disable it.
- **Breaks:** character key shortcuts (WCAG 2.1.4).
- **Change:** require a modifier (`⌘K` / `Ctrl+K`) or activate the shortcut only while the search button has focus.

**Settings is announced as a button, not a link**
- **What happens:** `Account → Settings` is a `Button` that toggles a sheet (`SchoolityApp.swift:137-156`), styled like a card row.
- **Why it matters:** VoiceOver reads "Settings, button" where every other destination in the app is a link, and the row loses the platform's navigation affordances.
- **Breaks:** match between system and real world (platform convention).
- **Change:** make the row a `NavigationLink`, as `Student ID` already is.

**The grade-history chart has no audio graph**
- **What happens:** the chart carries `.accessibilityLabel` and `.accessibilityValue` only (`GradebookViews.swift:602-603`), so VoiceOver hears one sentence.
- **Why it matters:** a blind student cannot explore individual points, only the summary, while every other figure in the app is readable item by item.
- **Breaks:** perceivable (a non-text alternative for a chart).
- **Change:** add a chart descriptor, or expose the points as the screen-reader list the web trend already provides.

**Inbox's empty state says "No mail"**
- **What happens:** the empty state builds its title from `resource.title.lowercased()` (`ResourceViews.swift:23`), so Inbox reads "No mail" and Documents "No documents".
- **Why it matters:** next to the search field it reads as truncated output rather than a sentence, on the screen a student sees before any messages exist.
- **Breaks:** match between system and real world (copy).
- **Change:** name each list in full — "No messages", "No documents".

**The inbox filter resets when you leave the section**
- **What happens:** `navigate()` clears `inboxFilter` (`+page.svelte`), so checking a course and coming back loses the filter and the narrowed list.
- **Why it matters:** the student repeats the search they had already narrowed.
- **Breaks:** user control and freedom (returning to a half-finished task).
- **Change:** keep the filter for the session, and clear it only on sign-out.

### Cosmetic

**Two accent modifiers, where the later one wins**
- **What happens:** `SchoolityApp` sets `.tint(SchoolityStyle.accent)` and then `.accentColor(Color("ActionAccent"))`; `WorkspaceView` repeats both with the same value.
- **Why it matters:** the first line reads as the app's accent and is not; the next person will edit it and see nothing change.
- **Breaks:** consistency and standards (a single source for the accent).
- **Change:** keep one of the two per view.

## Positive Findings

- Failure copy names its case and suggests the next step: an ended session, rejected credentials, an HTTP status, an unsupported format, each with Retry beside it, and no school data is cleared by a failure.
- The district grade and the Schoolity estimate are labelled separately on both surfaces, and a hypothetical change moves only the estimate.
- Dynamic Type is designed for, not tolerated: the summary card, course rows and record tables restack at accessibility sizes, and the course row drops its icon tile there.
- Reduce Motion swaps each spring for a short fade rather than removing the feedback.
- The rendered signed-out page has one `h1`, two `h2`, one `main`, a skip link, and every input labelled with an explicit `<label for>`; the remember-me box is `aria-describedby` linked to its explanation.
- Contrast holds: muted text is 6.6:1 on white and 7.3:1 on the dark panel; the faintest caption is 4.8:1, which passes AA for normal text.
- No dark patterns.

## Code review (SwiftUI) — from `swiftui-pro`

| File / line | Rule | Fix |
|---|---|---|
| `GradebookViews.swift:107`, `TermLine` body, `ScheduleView.swift:88` | Avoid `Binding(get:set:)` in a view body; bind directly and move the side effect to `onChange` | Give `SchoolityMenu` a value plus a `select` closure, or move the side effect into `onChange(of:)` |
| `GradebookViews.swift` (13 types, 836 lines), `RecordViews.swift` (1024), `InterfaceStyle.swift` (754) | Break different types into different files | Split by row, screen and token family |
| `AppStore.swift` | One `ObservableObject` for the whole app; prefer `@Observable` and per-feature state | Split into gradebook, records and session models |
| `SchoolityApp.swift:86-87` | `.toolbarBackground(..., for: .tabBar)` with `.visible` opts the tab bar out of the iOS 26 system material, while the navigation bar already uses `.automatic` on iOS 26 | Let the tab bar use the system material on iOS 26, as `schoolityNavigationChrome()` does for the nav bar |
| `AppStore.swift:263-266`, `GradebookViews.swift:95` | Long parameter lists and view builders inline in a large type | Extract the assignment-observer and the failure row into their own types |

Kept deliberately: `SchoolityMenu` uses a popover rather than a `Menu`, with the reason written in its doc comment — a card row would resize or clip a native menu, and the popover keeps the trigger's size.

## States (from `fortify`)

- Partial state is real and handled: each resource, record and section fails on its own and keeps its retry.
- Offline has no dedicated state; a failed request becomes the named failure card with the next-step line. No offline cache exists, which `README.md` states.
- Overflow: 50 messages and long histories are `List`-backed and deferred; the web collapses its table into labelled blocks below 1000px.
- Internationalization readiness is out of scope for a single-district US product, and dates are already locale-formatted.
- First use: the estimate rule is stated above the course rows, with "About estimates" one tap inside a course.

## Not covered

- Real district responses, saved-sign-in renewal on hardware, and every rendered screen (no browser, no readable simulator).
- The web's signed-in surface, which needs a StudentVUE account.
