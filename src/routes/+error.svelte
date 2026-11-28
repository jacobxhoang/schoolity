<script lang="ts">
  import { page } from "$app/state";
  import "./tokens.css";

  const title = $derived(
    page.status === 404
      ? "Page not found"
      : page.status === 403
        ? "Not available"
        : "Something went wrong",
  );
  const message = $derived(
    page.status === 404
      ? "That address is not part of Schoolity. Open your workspace to continue."
      : page.error?.message || "The page could not be loaded. Try again.",
  );
</script>

<svelte:head><title>{title} · Schoolity</title></svelte:head>

<main class="error-page">
  <div class="error-card">
    <span class="error-mark" aria-hidden="true">S</span>
    <p class="error-status">{page.status}</p>
    <h1>{title}</h1>
    <p class="error-message">{message}</p>
    <a class="error-action" href="/">Back to Schoolity</a>
  </div>
</main>

<style>
  .error-page {
    display: grid;
    place-items: center;
    min-height: 100dvh;
    padding: var(--s4);
  }
  .error-card {
    width: min(430px, 100%);
    padding: var(--s5) var(--s4);
    border: 1px solid var(--line);
    border-radius: var(--r-lg);
    background: var(--panel);
    box-shadow: var(--shadow);
  }
  .error-mark {
    display: grid;
    place-items: center;
    width: 44px;
    height: 44px;
    border-radius: var(--r-chip);
    background: var(--ink);
    color: var(--panel);
    font-family: var(--font-display);
    font-size: var(--t-h2);
    font-weight: 600;
  }
  .error-status {
    margin-top: var(--s4);
    color: var(--faint);
    font-size: var(--t-mini);
    font-weight: 600;
    letter-spacing: 0.08em;
  }
  h1 {
    margin-top: 4px;
    font-family: var(--font-display);
    font-size: var(--t-h1);
    letter-spacing: -0.02em;
  }
  .error-message {
    margin-top: var(--s2);
    color: var(--muted);
  }
  .error-action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: var(--s6);
    margin-top: var(--s4);
    padding: 0 18px;
    border-radius: var(--r-chip);
    background: var(--ink);
    color: var(--panel);
    font-size: var(--t-meta);
    font-weight: 600;
  }
  .error-action:hover {
    opacity: 0.88;
  }
</style>
