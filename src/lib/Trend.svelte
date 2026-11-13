<script lang="ts">
  import { chartRange } from './workspace';
  let {
    values = [],
    dates = [],
    large = false,
  }: { values?: number[]; dates?: string[]; large?: boolean } = $props();
  const width = 600,
    height = 160;
  const clean = $derived(values.filter(Number.isFinite));
  const range = $derived(chartRange(clean));
  const points = $derived(
    clean
      .map(
        (value, i) =>
          `${clean.length > 1 ? (i / (clean.length - 1)) * width : width / 2},${height - 8 - ((value - range.low) / (range.high - range.low)) * (height - 16)}`,
      )
      .join(' '),
  );
  const summary = $derived(
    clean.length
      ? `Calculated grade changed from ${clean[0].toFixed(1)}% to ${clean.at(-1)!.toFixed(1)}%, with a low of ${Math.min(...clean).toFixed(1)}% and a high of ${Math.max(...clean).toFixed(1)}% across ${clean.length} scored assignments.`
      : 'No scored assignments are available for a trend.',
  );
  const date = (value: string) => {
    const parsed = new Date(value);
    return Number.isFinite(parsed.getTime())
      ? parsed.toLocaleDateString([], { month: 'short', day: 'numeric' })
      : value;
  };
</script>

<figure class="grade-trend" class:large>
  {#if clean.length}
    <div class="trend-visual">
      {#if large}<div class="trend-ticks" aria-hidden="true">
          <span>{range.high.toFixed(0)}%</span><span
            >{((range.high + range.low) / 2).toFixed(0)}%</span
          ><span>{range.low.toFixed(0)}%</span>
        </div>{/if}
      <svg
        viewBox={`0 0 ${width} ${height}`}
        role="img"
        aria-label={summary}
        preserveAspectRatio="none"
      >
        {#if large}{#each [8, 80, 152] as y}<line
              x1="0"
              x2={width}
              y1={y}
              y2={y}
              stroke="currentColor"
              opacity=".18"
              stroke-dasharray="4 5"
            />{/each}{/if}
        {#if clean.length === 1}<circle
            cx={width / 2}
            cy={height -
              8 -
              ((clean[0] - range.low) / (range.high - range.low)) *
                (height - 16)}
            r="3"
            fill="currentColor"
          />{:else if clean.length}<polyline
            {points}
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            vector-effect="non-scaling-stroke"
          />{/if}
      </svg>
    </div>
    {#if large}<div class="trend-dates">
        <span>{dates[0] ? date(dates[0]) : 'First scored assignment'}</span
        ><span
          >{dates.at(-1)
            ? date(dates.at(-1)!)
            : 'Latest scored assignment'}</span
        >
      </div>
      <figcaption class="sr-only">{summary}</figcaption>{/if}
  {:else}<p class="trend-empty">No scored assignments yet.</p>{/if}
</figure>
