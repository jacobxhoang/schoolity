# Schoolity interface

Software: a student gradebook and school-records application for Anoka-Hennepin.

## Direction

Use a monochrome web palette in light and dark mode. Sidebar, summary, course icons, and custom dropdowns share neutral surfaces and black-and-white selection states. The signed-in iOS app carries the same palette, flat card surfaces, and type hierarchy in Dynamic Type system faces. Its sign-in screens use the same dark canvas and ink accent in every appearance; only the workspace follows the Light, Dark, or System preference. Native iOS accent settings remain independent. Inter and Inter Tight remain the web faces. The product's live grades, assignments, schedules, and records carry each screen. Preserve all routes, calculations, authentication, and data fields. No marketing hero, photographs, decorative effects, timed content, or invented figures belong in the signed-in application.

The main action is opening a course. Put the course title and secondary teacher/location details on the left and a readable grade on the right. At accessibility text sizes, stack these elements in reading order. The iOS login and saved-sign-in screens use the website's dark panel and ink accent, with the district and StudentVUE context kept above the credential card.

## Shared system

- Lightly tinted canvas, one surface level, fine separators, consistent 16–20 point/pixel surface corners. Keep dark mode equally restrained, with brighter text and neutral icon marks.
- A 44 point/pixel minimum control target and a visible keyboard focus ring on the web.
- Equal page gutters. Mobile layouts stack before text or controls become compressed.
- Course grades use tabular numerals, clear weight, and restrained color; the graph line keeps its fixed Schoolity color.
- Supporting text remains legible. Web body text is 15–16 pixels, metadata at least 13 pixels; iOS uses semantic fonts and Dynamic Type.
- Native grouped lists organize preferences; records reuse the workspace cards. Avoid repeated nested panels, prominent shadows, and duplicated headers.
- Interactive web course rows lift subtly on hover. Preserve reduced-motion support and immediate keyboard feedback.

## Screens

Gradebook: compact summary, reporting-period selection, courses, and the existing web recent-assignment sidebar. Both surfaces carry the same summary and recent assignments; iOS presents them as card rows where the web places a sidebar. Its summary is the website's flat panel: a grade ring beside the exact average and the course count. The signed-in iOS canvas uses the website's tinted canvas (#F7F7F8), near-black (#111113) in Dark Mode, with white or #1A1A1D panels.

Course: clear grade heading, assignments/breakdown control, grade history, and hypothetical editing only in Assignments. Every workspace screen keeps the website's refresh control, count badges, loading placeholders, dismissible failures, and the privacy connection-details disclosure.

Records and account: reuse the same surface, row spacing, icon treatment, and heading scale. All district-provided information remains available.

## Voice and verification

Use short factual labels: Gradebook, School grade, Course History, Add hypothetical score. Preserve the district's content. Test fixtures use synthetic student records outside production; they are not product claims.

Review the web at 1440, 1024, 768, 390, and 320 pixels, including light/dark and signed-in/out states. Review iOS simulator screenshots in light mode and Dark Mode at accessibility text size. The design-taste marketing-page checks may flag missing heroes, full-screen sections, or staged effects; those do not apply to a working student dashboard and must be reported separately from functional accessibility or overflow defects.
