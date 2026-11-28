<script lang="ts">
  import "../tokens.css";
  let { data } = $props();
  const evaluation = $derived(
    data.records.filter((entry) => entry.kind === "evaluation"),
  );
  const runs = $derived(
    data.records.filter((entry) => entry.kind === "critique"),
  );
  const selected = $derived(
    data.records.find((entry) => entry.slug === data.selected),
  );
</script>

<svelte:head><title>Design notes · Schoolity</title></svelte:head>

<main class="design-page">
  <header>
    <h1>Design notes</h1>
    <p>
      The evaluation and the critique runs kept in <code>.impeccable</code>.
      They load only while Schoolity runs on this machine; the folder is
      excluded from deployment, so this page does not exist in production.
    </p>
    <a class="back" href="/">Back to Schoolity</a>
  </header>

  <div class="design-body">
    <nav aria-label="Design records">
      {#if evaluation.length}<ul>
          {#each evaluation as entry (entry.slug)}<li>
              <a
                class:active={entry.slug === data.selected}
                href={`?doc=${entry.slug}`}
                aria-current={entry.slug === data.selected ? "page" : undefined}
              >
                <span>{entry.title}</span>
                <small>{entry.meta}</small>
              </a>
            </li>{/each}
        </ul>{/if}
      {#if runs.length}
        <p class="group-label">Critique runs</p>
        <ul>
          {#each runs as entry (entry.slug)}<li>
              <a
                class:active={entry.slug === data.selected}
                href={`?doc=${entry.slug}`}
                aria-current={entry.slug === data.selected ? "page" : undefined}
              >
                <span>{entry.title}</span>
                <small>{entry.meta}</small>
              </a>
            </li>{/each}
        </ul>
      {/if}
    </nav>

    <article>
      {#if selected}
        <h2>{selected.title}</h2>
        <p class="doc-meta">{selected.meta}</p>
        <pre>{data.body}</pre>
      {:else}
        <p class="empty">No design records were found.</p>
      {/if}
    </article>
  </div>
</main>

<style>
  .design-page {
    max-width: 1200px;
    margin: 0 auto;
    padding: var(--s4) var(--gutter) var(--s6);
  }
  header h1 {
    font-family: var(--font-display);
    font-size: var(--t-page);
    letter-spacing: -0.04em;
  }
  header p {
    max-width: 72ch;
    margin-top: 8px;
    color: var(--muted);
  }
  header code {
    font-size: var(--t-mini);
  }
  .back {
    display: inline-flex;
    align-items: center;
    min-height: var(--s6);
    margin-top: 6px;
    color: var(--muted);
    font-size: var(--t-meta);
    text-decoration: underline;
    text-underline-offset: 3px;
  }
  .back:hover {
    color: var(--ink);
  }
  .design-body {
    display: grid;
    grid-template-columns: 220px minmax(0, 1fr);
    align-items: start;
    gap: var(--s4);
    margin-top: var(--s4);
  }
  nav ul {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin: 0;
    padding: 0;
    list-style: none;
  }
  .group-label {
    margin: 14px 0 4px;
    padding: 0 12px;
    color: var(--muted);
    font-size: var(--t-mini);
    font-weight: 500;
  }
  nav a {
    display: block;
    padding: 10px 12px;
    border-radius: var(--r-chip);
    color: var(--muted);
    font-size: var(--t-meta);
    line-height: 1.4;
  }
  nav a:hover {
    background: var(--field);
    color: var(--ink);
  }
  nav a.active {
    background: var(--ink);
    color: var(--on-ink);
  }
  nav small {
    display: block;
    margin-top: 2px;
    color: inherit;
    font-size: var(--t-mini);
  }
  nav a.active small {
    opacity: 0.75;
  }
  article {
    min-width: 0;
    padding: 20px;
    border: 1px solid var(--line);
    border-radius: var(--r);
    background: var(--panel);
  }
  article h2 {
    font-family: var(--font-display);
    font-size: var(--t-h2);
    letter-spacing: -0.02em;
  }
  .doc-meta {
    margin-top: 4px;
    color: var(--muted);
    font-size: var(--t-mini);
  }
  .empty {
    margin-top: 12px;
    color: var(--muted);
    font-size: var(--t-meta);
  }
  pre {
    margin-top: 14px;
    color: var(--ink);
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: var(--t-mini);
    line-height: 1.6;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
  }
  @media (max-width: 760px) {
    .design-body {
      grid-template-columns: minmax(0, 1fr);
    }
  }
</style>
