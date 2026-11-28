# Schoolity interface

Software: a student gradebook and school-records application for Anoka-Hennepin.

## Direction

Use a monochrome web palette in light and dark mode. Sidebar, summary, course icons, and custom dropdowns share neutral surfaces and black-and-white selection states. The signed-in iOS app carries the same palette, flat card surfaces, and type hierarchy in Dynamic Type system faces. Its sign-in screens use the same dark canvas and ink accent in every appearance; only the workspace follows the Light, Dark, or System preference. Native iOS accent settings remain independent. Inter and Inter Tight remain the web faces. The product's live grades, assignments, schedules, and records carry each screen. Preserve all routes, calculations, authentication, and data fields. No marketing hero, photographs, decorative effects, timed content, or invented figures belong in the signed-in application.

The main action is opening a course. Put the course title and secondary teacher/location details on the left and a readable grade on the right. At accessibility text sizes, stack these elements in reading order. The iOS login and saved-sign-in screens use the website's dark panel and ink accent, with the district and StudentVUE context kept above the credential card.

The web sign-in surface holds its light palette on the signed-out shell rather than on the page, so the Privacy and Account dialogs opened from it stay light and never follow the workspace theme. Its rail lists the workspace's surfaces as plain text, with no mock grades, percentages, or other invented figures. A filled ink control takes its text, hover, and pressed values from tokens, so no surface restates a palette.

## Shared system

- Lightly tinted canvas, one surface level, fine separators, consistent 16–20 point/pixel surface corners. Keep dark mode equally restrained, with brighter text and neutral icon marks.
- A 44 point/pixel minimum control target and a visible keyboard focus ring on the web.
- Equal page gutters. Mobile layouts stack before text or controls become compressed.
- Course grades use tabular numerals, clear weight, and restrained color; the graph line keeps its fixed Schoolity color.
- Supporting text remains legible. Web body text is 15–16 pixels, metadata at least 13 pixels; iOS uses semantic fonts and Dynamic Type.
- One type scale carries every size. Body, metadata, headings, page titles, large figures, and brand marks read from tokens, and nothing renders below 13 pixels on the web.
- One dropdown pattern on iOS: a choice opens the app's floating list, never a native menu inside a card row. The segmented control stays only for switching sections on one screen.
- A hypothetical score is accepted only when it reads as a non-negative number. Unreadable input stays in the field with an inline hint and never moves the estimate; web and iPhone behave the same way.
- The gradebook summary is the mean of the course estimates beside the course count. Name it plainly as the course average; never label it unweighted or imply GPA weighting.
- Web navigation mirrors the iPhone's tabs: Gradebook and Schedule first, then Records (Student Info, Attendance, Course History, Documents), then Messages (Inbox). Documents are records, not messages, on both surfaces.
- Long-press is never the only path to class customization: the course screen carries a Customize action in its toolbar, and a schedule row shows a paintbrush control beside its period.
- The gradebook's course rows show Schoolity estimates, and one line above the rows says so; the district's grade appears on the course screen beside the estimate.
- About estimates is available on both surfaces, in the course header on the web and as a disclosure on the course screen on iPhone. It states what the estimate uses and that the school grade never changes.
- A hypothetical reset can be undone in one tap on the web, and a score above the points possible says so next to the figure without blocking the trial.
- Section failures name the section and keep the retry beside them. They are pinned above the section's content, so a refresh that fails while stale grades are still on screen says so without scrolling. A section that is still loading shows its placeholder rather than an empty card.
- Spacing follows the 4 point ramp in `SchoolitySpace`: card padding, page gutters and row insets read from it, so a row does not invent its own rhythm.
- A field's resting border is `--field-line`, at least 3:1 against the surface around it, and focus still draws the ink outline. The iPhone raises its login and select field borders for the same reason.
- A row that opens another screen is announced as a link, and each point of the grade history is its own VoiceOver element.
- Workspace search opens from the header or with `Command-K` (Control-K on Windows), reads only data already in page memory, and never asks the district for anything. A result opens its course, class, message or document, and a message result also narrows the inbox to it. On iPhone the inbox and document lists carry a search field over the rows already loaded.
- Only the gradebook uses the top status toast, and it names the gradebook. Every other section shows its own placeholder and disabled refresh instead of a second status.
- The iPhone reads every text and glyph size from `SchoolityText`, including an icon scale for chevrons; no view names a font directly.
- Native grouped lists organize preferences; records reuse the workspace cards. Avoid repeated nested panels, prominent shadows, and duplicated headers.
- Interactive web course rows lift subtly on hover. Preserve reduced-motion support and immediate keyboard feedback.

## Screens

Gradebook: compact summary, reporting-period selection, courses, and the existing web recent-assignment sidebar. Both surfaces carry the same summary and recent assignments; iOS presents them as card rows where the web places a sidebar. Its summary is the website's flat panel: a grade ring beside the exact average and the course count. The signed-in iOS canvas uses the website's tinted canvas (#F7F7F8), near-black (#111113) in Dark Mode, with white or #1A1A1D panels.

Course: clear grade heading, assignments/breakdown control, grade history, and hypothetical editing only in Assignments. Both surfaces put the district's school grade beside the Schoolity estimate; hypothetical changes move only the estimate. Every workspace screen keeps the website's refresh control, count badges, loading placeholders, dismissible failures, and the privacy connection-details disclosure.

Records and account: reuse the same surface, row spacing, icon treatment, and heading scale. All district-provided information remains available.

## Voice and verification

Use short factual labels: Gradebook, School grade, Course History, Add hypothetical score. Preserve the district's content. Test fixtures use synthetic student records outside production; they are not product claims.

Review the web at 1440, 1024, 768, 390, and 320 pixels, including light/dark and signed-in/out states. Review iOS simulator screenshots in light mode and Dark Mode at accessibility text size. The design-taste marketing-page checks may flag missing heroes, full-screen sections, or staged effects; those do not apply to a working student dashboard and must be reported separately from functional accessibility or overflow defects.
