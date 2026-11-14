<script lang="ts">
  import { calculate, percentage, type Course } from './model';
  import { scoreChange } from './workspace';
  let {
    course,
    starting,
    scenario = false,
  }: { course: Course; starting: Course; scenario?: boolean } = $props();
  const estimate = $derived(calculate(course));
  const baseline = $derived(calculate(starting));
  const change = $derived(
    estimate !== null && baseline !== null ? estimate - baseline : null,
  );
</script>

<section class="grade-comparison" aria-label="Course grade comparison">
  <div>
    <span>District grade</span><strong>{percentage(starting.official)}</strong>
    {#if starting.official === null}<small>Not available</small>{/if}
  </div>
  <div class:scenario>
    <span>{scenario ? 'Hypothetical estimate' : 'Schoolity estimate'}</span><strong
      >{percentage(estimate)}</strong
    >{#if scenario}<small aria-label={scoreChange(estimate, baseline)}
        >{change === null
          ? 'No comparison'
          : `${change >= 0 ? '+' : '−'}${Math.abs(change).toFixed(1)} pts`}</small
      >{/if}
  </div>
</section>
