<script lang="ts">
  import { tick } from "svelte";
  import Icon from "./Icon.svelte";

  let {
    value = $bindable(""),
    options,
    label,
    id,
    onchange,
  }: {
    value?: string;
    options: { value: string; label: string }[];
    label: string;
    id?: string;
    onchange?: (value: string) => void;
  } = $props();
  const uid = $props.id();
  let trigger: HTMLButtonElement;
  let menu: HTMLDivElement;
  let open = $state(false);
  let search = "";
  let searchTime = 0;
  const selected = $derived(options.find((option) => option.value === value));

  function close() {
    menu?.hidePopover();
  }
  function choose(next: string) {
    value = next;
    onchange?.(next);
    close();
    trigger.focus();
  }
  async function show(last = false) {
    if (!options.length) return;
    const rect = trigger.getBoundingClientRect();
    const below = window.innerHeight - rect.bottom - 12;
    const above = rect.top - 12;
    const upward = below < 180 && above > below;
    menu.style.setProperty(
      "--menu-left",
      `${Math.max(8, Math.min(rect.left, window.innerWidth - Math.max(rect.width, 200) - 8))}px`,
    );
    menu.style.setProperty(
      "--menu-width",
      `${Math.min(Math.max(rect.width, 200), window.innerWidth - 16)}px`,
    );
    menu.style.setProperty(
      "--menu-height",
      `${Math.max(44, Math.min(320, upward ? above : below))}px`,
    );
    menu.style.top = upward ? "auto" : `${rect.bottom + 6}px`;
    menu.style.bottom = upward
      ? `${window.innerHeight - rect.top + 6}px`
      : "auto";
    menu.showPopover();
    await tick();
    const buttons = menu.querySelectorAll<HTMLButtonElement>('[role="option"]');
    const index = options.findIndex((option) => option.value === value);
    buttons[last ? buttons.length - 1 : Math.max(0, index)]?.focus();
  }
  function navigate(event: KeyboardEvent) {
    const buttons = [
      ...menu.querySelectorAll<HTMLButtonElement>('[role="option"]'),
    ];
    const current = buttons.indexOf(
      document.activeElement as HTMLButtonElement,
    );
    let next = current;
    if (event.key === "ArrowDown") next = (current + 1) % buttons.length;
    else if (event.key === "ArrowUp")
      next = (current - 1 + buttons.length) % buttons.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = buttons.length - 1;
    else if (event.key === "Tab") {
      close();
      trigger.focus();
      return;
    } else if (event.key === "Escape") {
      event.preventDefault();
      close();
      trigger.focus();
      return;
    } else if (
      event.key.length === 1 &&
      !event.ctrlKey &&
      !event.metaKey &&
      event.key !== " "
    ) {
      search =
        (Date.now() - searchTime > 700 ? "" : search) +
        event.key.toLocaleLowerCase();
      searchTime = Date.now();
      next = options.findIndex((option) =>
        option.label.toLocaleLowerCase().startsWith(search),
      );
    } else return;
    event.preventDefault();
    buttons[next]?.focus();
  }
</script>

<svelte:window onresize={close} onscroll={close} />
<button
  bind:this={trigger}
  {id}
  type="button"
  class="select-trigger"
  aria-label={label}
  aria-haspopup="listbox"
  aria-expanded={open}
  aria-controls={`${uid}-options`}
  disabled={!options.length}
  onclick={() => (open ? close() : void show())}
  onkeydown={(event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      void show(event.key === "ArrowUp");
    }
  }}
>
  <span>{selected?.label ?? "Choose an option"}</span><span
    class:expanded={open}><Icon name="chevron" size={14} /></span
  >
</button>
<div
  bind:this={menu}
  id={`${uid}-options`}
  class="select-menu"
  popover="auto"
  role="listbox"
  aria-label={label}
  tabindex="-1"
  onkeydown={navigate}
  ontoggle={(event) => {
    open = event.newState === "open";
  }}
>
  {#each options as option}
    <button
      type="button"
      role="option"
      aria-selected={value === option.value}
      tabindex="-1"
      onclick={() => choose(option.value)}
      ><span>{option.label}</span>
      {#if value === option.value}<Icon name="check" size={16} />{/if}
    </button>
  {/each}
</div>

<style>
  .select-trigger {
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 44px;
    max-width: 100%;
    padding: 0 12px;
    border: 1px solid var(--line-strong);
    border-radius: var(--r-chip);
    background: var(--field);
    color: var(--ink);
    font-size: var(--t-meta);
    text-align: left;
  }
  .select-trigger > span:first-child {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .select-trigger > span:last-child {
    display: flex;
    transform: rotate(90deg);
    transition: transform 150ms ease;
  }
  .select-trigger > span.expanded {
    transform: rotate(-90deg);
  }
  .select-trigger:hover {
    border-color: var(--line-strong);
  }
  .select-menu {
    position: fixed;
    inset: auto;
    left: var(--menu-left);
    width: var(--menu-width);
    max-height: var(--menu-height);
    overflow-y: auto;
    overscroll-behavior: contain;
    margin: 0;
    padding: 6px;
    border: 1px solid var(--line-strong);
    border-radius: 12px;
    background: var(--elevated);
    color: var(--ink);
    box-shadow: 0 12px 32px rgb(0 0 0 / 0.18);
  }
  .select-menu button {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    width: 100%;
    min-height: 44px;
    padding: 10px 12px;
    border-radius: 7px;
    font-size: var(--t-meta);
    text-align: left;
    overflow-wrap: anywhere;
  }
  .select-menu button[aria-selected="true"] {
    background: var(--accent-soft);
    color: var(--accent-ink);
    font-weight: 600;
  }
  .select-menu button:hover,
  .select-menu button:focus-visible {
    background: var(--field);
    outline: 2px solid var(--accent);
    outline-offset: -2px;
  }
  @media (prefers-reduced-motion: no-preference) {
    .select-menu:popover-open {
      animation: menu-enter 120ms ease-out;
    }
    @keyframes menu-enter {
      from {
        opacity: 0;
        transform: translateY(-4px);
      }
      to {
        opacity: 1;
        transform: none;
      }
    }
  }
</style>
