<script lang="ts">
  import { calculate, percentage, type Course } from "./model";
  import { scoreChange } from "./workspace";
  let {
    course,
    starting,
    official = null,
    scenario = false,
  }: {
    course: Course;
    starting: Course;
    official?: number | null;
    scenario?: boolean;
  } = $props();
  const estimate = $derived(calculate(course));
  const baseline = $derived(calculate(starting));
  const change = $derived(
    estimate !== null && baseline !== null ? estimate - baseline : null,
  );
</script>

<section
  class="grade-comparison"
  aria-label="District grade and Schoolity estimate"
>
  <div>
    <span>School grade</span>
    <strong>{percentage(official)}</strong>
    <small>Reported by the district</small>
  </div>
  <div class:scenario>
    {#if scenario}<span>Hypothetical estimate</span>{:else}<span
        >Schoolity estimate</span
      >{/if}<strong>{percentage(estimate)}</strong>
    {#if scenario}<small aria-label={scoreChange(estimate, baseline)}
        >{change === null
          ? "No comparison"
          : `${change >= 0 ? "+" : "−"}${Math.abs(change).toFixed(1)} pts`}</small
      >{/if}
  </div>
</section>
