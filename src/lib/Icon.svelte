<script lang="ts">
  let { name = "grid", size = 20 }: { name?: string; size?: number } = $props();
  const paths: Record<string, string> = {
    grid: "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
    book: "M4 4h7a3 3 0 0 1 3 3v14a4 4 0 0 0-4-2H4z M14 7a3 3 0 0 1 3-3h4v15h-3a4 4 0 0 0-4 2",
    calendar: "M5 5h14v16H5z M8 2v6 M16 2v6 M5 10h14",
    person: "M20 21v-2a7 7 0 0 0-14 0v2 M17 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
    history: "M3 3v6h6 M3 9a9 9 0 1 1 1 9 M12 7v5l3 2",
    clock: "M12 8v5l3 2 M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0",
    check: "m5 12 4 4L19 6",
    mail: "M3 5h18v14H3z m0 0 9 8 9-8",
    file: "M6 3h8l4 4v14H6z M14 3v5h4 M9 12h6 M9 16h6",
    arrow: "M5 12h14 m-5-5 5 5-5 5",
    search: "M20 20l-5-5 M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0",
    plus: "M12 5v14 M5 12h14",
    close: "m6 6 12 12 M18 6 6 18",
    logout: "M9 4H4v16h5 M10 12h11 m-4-4 4 4-4 4",
    sun: "M12 2v2 M12 20v2 M2 12h2 M20 12h2 M5 5l2 2 M17 17l2 2 M5 19l2-2 M17 7l2-2 M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
    moon: "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
    chevron: "m9 5 7 7-7 7",
    shield: "M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6z m-4 9 3 3 5-6",
    menu: "M4 6h16 M4 12h16 M4 18h16",
  };
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="1.6"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"><path d={paths[name] ?? paths.grid} /></svg
>
