<script lang="ts">
  import { chartRange } from "./workspace";
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
      .join(" "),
  );
  const plotted = $derived(
    clean.map((value, index) => {
      const fraction = (value - range.low) / (range.high - range.low);
      return {
        value,
        index,
        x: clean.length > 1 ? (index / (clean.length - 1)) * 100 : 50,
        y: ((height - 8 - fraction * (height - 16)) / height) * 100,
      };
    }),
  );
  // Many graded assignments put more labels on the line than the line can hold,
  // so a dense graph labels only its latest point. The figure's screen-reader
  // list still carries every value.
  const dense = $derived(plotted.length > 6);
  const summary = $derived(
    clean.length
      ? `Calculated grade changed from ${clean[0].toFixed(1)}% to ${clean.at(-1)!.toFixed(1)}%, with a low of ${Math.min(...clean).toFixed(1)}% and a high of ${Math.max(...clean).toFixed(1)}% across ${clean.length} scored assignments.`
      : "No scored assignments are available for a trend.",
  );
  const date = (value: string) => {
    const parsed = new Date(value);
    return Number.isFinite(parsed.getTime())
      ? parsed.toLocaleDateString([], { month: "short", day: "numeric" })
      : value;
  };
  const pointDate = (index: number) =>
    dates[index] ? date(dates[index]) : `Assignment ${index + 1}`;
</script>

<figure class="grade-trend" class:large>
  {#if clean.length}
    <div class="trend-visual">
      {#if large}<div class="trend-ticks" aria-hidden="true">
          <span>{range.high.toFixed(0)}%</span><span
            >{((range.high + range.low) / 2).toFixed(0)}%</span
          ><span>{range.low.toFixed(0)}%</span>
        </div>{/if}
      <div class="trend-plot">
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
          {#if clean.length > 1}<polyline
              {points}
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              vector-effect="non-scaling-stroke"
            />{/if}
        </svg>
        <div class="trend-points" aria-hidden="true">
          {#each plotted as point (point.index)}<span
              class="trend-point"
              class:first={point.index === 0}
              class:last={point.index === plotted.length - 1}
              style={`left:${point.x}%;top:${point.y}%`}
              ><span class="trend-dot"
              ></span>{#if !dense || point.index === plotted.length - 1}<span
                  class="trend-point-label"
                  class:below={(point.index % 2 === 1 || point.y < 12) &&
                    point.y < 84}>{point.value.toFixed(1)}%</span
                >{/if}</span
            >{/each}
        </div>
      </div>
    </div>
    {#if large}<div class="trend-dates">
        <span>{dates[0] ? date(dates[0]) : "First scored assignment"}</span
        ><span
          >{dates.at(-1)
            ? date(dates.at(-1)!)
            : "Latest scored assignment"}</span
        >
      </div>
      <figcaption class="sr-only">{summary}</figcaption>{/if}
    <ul class="sr-only">
      {#each plotted as point (point.index)}<li>
          {pointDate(point.index)}: {point.value.toFixed(1)}%
        </li>{/each}
    </ul>
  {:else}<p class="trend-empty">No scored assignments yet.</p>{/if}
</figure>

<style>
  .trend-plot {
    position: relative;
    flex: 1;
    min-width: 0;
    height: 150px;
  }
  .trend-plot > svg {
    display: block;
    width: 100%;
    height: 100%;
    flex: none;
    overflow: visible;
  }
  .trend-points {
    position: absolute;
    inset: 0;
    pointer-events: none;
  }
  .trend-point {
    position: absolute;
    width: 0;
    height: 0;
  }
  .trend-dot {
    position: absolute;
    top: 0;
    left: 0;
    z-index: 2;
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: currentColor;
    box-shadow: 0 0 0 2px var(--panel, #fff);
    transform: translate(-50%, -50%);
  }
  .trend-point-label {
    position: absolute;
    bottom: 7px;
    left: 50%;
    z-index: 1;
    padding: 1px 4px;
    border-radius: 4px;
    background: var(--panel, #fff);
    color: var(--ink, #0f0f0f);
    font-size: var(--t-mini);
    font-weight: 500;
    font-variant-numeric: tabular-nums;
    line-height: 1.4;
    white-space: nowrap;
    transform: translateX(-50%);
  }
  .trend-point-label.below {
    top: 7px;
    bottom: auto;
  }
  .trend-point.first .trend-point-label {
    left: 0;
    transform: none;
  }
  .trend-point.last .trend-point-label {
    right: 0;
    left: auto;
    transform: none;
  }
  @media (max-width: 500px) {
    .trend-point-label {
      padding: 1px 3px;
    }
  }
</style>
