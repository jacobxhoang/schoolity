<script lang="ts">
  import { studentText, type RecordPage, type GraduationRequirement, type SubjectDetails } from './records';
  import Icon from './Icon.svelte';
  import SelectMenu from './SelectMenu.svelte';
  let { page, loadSubject }: { page: RecordPage; loadSubject: (id: string) => Promise<SubjectDetails> } = $props();
  let year = $state(''), school = $state('');
  let openSubject = $state<string | null>(null);
  let subjects = $state<Record<string, { loading: boolean; data?: SubjectDetails; error?: string }>>({});
  async function fetchSubject(key: string, requirement: GraduationRequirement) {
    if (!requirement.id) {
      subjects[key] = { loading: false, error: 'Your district did not provide a subject identifier. Refresh course history and try again.' };
      return;
    }
    subjects[key] = { ...subjects[key], loading: true, error: '' };
    try { subjects[key] = { loading: false, data: await loadSubject(requirement.id) }; }
    catch (error) { subjects[key] = { ...subjects[key], loading: false, error: error instanceof Error ? error.message : 'Could not load classes. Try again.' }; }
  }
  function toggleSubject(key: string, requirement: GraduationRequirement) {
    openSubject = openSubject === key ? null : key;
    if (openSubject === key && !subjects[key]) void fetchSubject(key, requirement);
  }
  const courses = $derived(page.kind === 'history' ? page.courses : []);
  const years = $derived([...new Set(courses.map(c => c.year).filter(Boolean))].sort().reverse());
  const schools = $derived([...new Set(courses.map(c => c.school).filter(Boolean))].sort());
  const shown = $derived(courses.filter(c => (!year || c.year === year) && (!school || c.school === school)));
  const date = (value: string) => {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? value || 'Date not provided' : parsed.toLocaleDateString([], {month:'short',day:'numeric',year:'numeric'});
  };
  const credit = (value: number | null) => value === null ? '—' : value.toFixed(2);
  function progress(requirement: GraduationRequirement) {
    const { required, completed, inProgress } = requirement;
    if (required === null || required <= 0 || completed === null) return null;
    const percent = Math.max(0, completed / required * 100);
    return { percent, completed: Math.min(100, percent),
      inProgress: Math.min(100 - Math.min(100, percent), Math.max(0, (inProgress ?? 0) / required * 100)) };
  }
</script>

{#if page.kind === 'student'}
  {#if page.notice}<p class="notice" role="status">{page.notice}</p>{/if}
  {#each page.sections as section}
    <section class="student-record-section" aria-label={section.title}>
      <h2>{section.title}</h2>
      <dl class="student-info-fields">
        {#each section.fields as field}<div><dt>{field.label}</dt><dd>{studentText(field.value) || 'Not provided'}</dd></div>{/each}
      </dl>
      {#each section.groups ?? [] as group}
        <div class="student-info-group"><h3>{group.title}</h3><dl class="student-info-fields">
          {#each group.fields as field}<div><dt>{field.label}</dt><dd>{studentText(field.value) || 'Not provided'}</dd></div>{/each}
        </dl></div>
      {/each}
      {#if section.table}<div class="table-wrap student-info-table"><table>
        <caption class="sr-only">{section.title}</caption>
        <thead><tr>{#each section.table.columns as column}<th>{column}</th>{/each}</tr></thead>
        <tbody>{#each section.table.rows as row}<tr>{#each row as value, index}<td data-label={section.table.columns[index]}>{studentText(value) || 'Not provided'}</td>{/each}</tr>{/each}</tbody>
      </table></div>{/if}
      {#if section.note}<p class="student-info-note">{studentText(section.note)}</p>{/if}
    </section>
  {:else}<p class="records-empty">No student information was returned by your district. Try refreshing.</p>{/each}
{:else if page.kind === 'history'}
  <section class="graduation-status" aria-labelledby="graduation-title">
    <div class="graduation-heading"><h2 id="graduation-title">Graduation status</h2>{#if page.classOf}<span>Class of {page.classOf}</span>{/if}</div>
    {#if page.requirements.length}
      <div class="graduation-legend" aria-label="Progress bar legend"><span><i class="completed-key"></i>Completed</span><span><i class="in-progress-key"></i>In progress</span><span><i class="remaining-key"></i>Remaining</span></div>
      <div class="graduation-columns" aria-hidden="true"><span>Subject area</span><span>Progress</span></div>
      <ul class="graduation-requirements">
        {#each page.requirements as requirement, index}
          {@const bar = progress(requirement)}
          {@const key = requirement.id || `subject-${index}`}
          <li class="graduation-requirement">
            <h3><button class="subject-toggle" aria-expanded={openSubject === key} aria-controls={`subject-classes-${index}`} onclick={() => toggleSubject(key, requirement)}><Icon name="chevron" size={16} /><span>{requirement.subject}</span></button></h3>
            <div class="graduation-progress">
              {#if bar}
                <div class="graduation-bar" role="progressbar" aria-label={requirement.subject} aria-valuemin="0" aria-valuemax={requirement.required!} aria-valuenow={Math.max(0, Math.min(requirement.required!, requirement.completed!))} aria-valuetext={`${credit(requirement.completed)} of ${credit(requirement.required)} credits completed${requirement.inProgress === null ? '' : `; ${credit(requirement.inProgress)} in progress`}`}>
                  <span class="graduation-completed" style:width={`${bar.completed}%`}></span><span class="graduation-in-progress" style:width={`${bar.inProgress}%`}></span>
                </div>
                <span class="graduation-percentage">{bar.percent.toFixed(1)}%</span>
              {:else}<span class="graduation-unavailable">Progress not provided</span>{/if}
              <dl class="graduation-credits">
                <div><dt>Required</dt><dd>{credit(requirement.required)}</dd></div>
                <div><dt>Completed</dt><dd>{credit(requirement.completed)}</dd></div>
                <div><dt>In progress</dt><dd>{credit(requirement.inProgress)}</dd></div>
                <div><dt>Remaining</dt><dd>{credit(requirement.remaining)}</dd></div>
              </dl>
            </div>
            <section id={`subject-classes-${index}`} class="subject-classes" hidden={openSubject !== key} aria-label={`${requirement.subject} classes`} aria-busy={subjects[key]?.loading ?? false}>
              {#if subjects[key]?.loading}<p role="status" class="records-intro">Loading classes…</p>{/if}
              {#if subjects[key]?.error}<div class="subject-error" role="alert"><p>{subjects[key].error}</p><button class="text-button" disabled={subjects[key].loading} onclick={() => fetchSubject(key, requirement)}>Retry</button></div>{/if}
              {#if subjects[key]?.data}
                {@const detail = subjects[key].data!}
                {#each [{label:'Completed', rows:detail.completed}, {label:'In progress', rows:detail.inProgress}] as group}
                  <div class="subject-course-group">
                    <h4>{group.label}</h4>
                    {#if group.rows.length}<div class="table-wrap subject-course-table"><table>
                      <caption class="sr-only">{group.label} classes for {requirement.subject}</caption>
                      <thead><tr>{#each detail.columns as column}<th>{column}</th>{/each}</tr></thead>
                      <tbody>{#each group.rows as row}<tr>{#each row as value, column}<td data-label={detail.columns[column]}>{value || '—'}</td>{/each}</tr>{/each}</tbody>
                    </table></div>
                    {:else}<p class="records-intro">No {group.label.toLowerCase()} classes were returned for this subject.</p>{/if}
                  </div>
                {/each}
              {/if}
            </section>
          </li>
        {/each}
      </ul>
    {:else}<p class="records-empty">Your district did not return graduation progress. Try refreshing to load it.</p>{/if}
  </section>
  <details class="history-course-records" open={page.requirements.length === 0}>
  <summary>Course records <span>{courses.length}</span></summary>
  <p class="records-intro">District-reported marks and credits from previous courses.</p>
  {#if courses.length}
    <div class="record-filters">
      <div class="record-filter"><label for="history-year">Year</label><SelectMenu id="history-year" label="Year" bind:value={year} options={[{value: '', label: 'All years'}, ...years.map(value => ({value, label: value}))]} /></div>
      <div class="record-filter"><label for="history-school">School</label><SelectMenu id="history-school" label="School" bind:value={school} options={[{value: '', label: 'All schools'}, ...schools.map(value => ({value, label: value}))]} /></div>
      <span role="status">{shown.length} {shown.length === 1 ? 'course' : 'courses'}</span>
    </div>
    {#if shown.length}
      <div class="table-wrap history-table">
        <table>
          <caption class="sr-only">Course history with district marks and attempted and completed credits</caption>
          <thead><tr><th>Course</th><th>School</th><th>Year / term</th><th>Grade level</th><th>Mark</th><th>Attempted credits</th><th>Completed credits</th></tr></thead>
          <tbody>{#each shown as course (course.id)}<tr>
            <td data-label="Course"><strong>{course.title || 'Untitled course'}</strong>{#if course.code}<small>{course.code}</small>{/if}</td>
            <td data-label="School">{course.school || '—'}</td>
            <td data-label="Year / term">{[course.year, course.term].filter(Boolean).join(' · ') || '—'}</td>
            <td data-label="Grade level">{course.grade || '—'}</td>
            <td data-label="Mark"><strong>{course.mark || '—'}</strong></td>
            <td data-label="Attempted credits">{credit(course.attempted)}</td>
            <td data-label="Completed credits">{credit(course.completed)}</td>
          </tr>{/each}</tbody>
        </table>
      </div>
    {:else}<div class="records-empty"><p>No courses match these filters.</p><button class="text-button" onclick={() => {year = ''; school = '';}}>Clear filters</button></div>{/if}
  {:else}<p class="records-empty">No course history was returned by your district.</p>{/if}
  </details>
{:else if page.kind === 'attendance'}
  {#if page.totals.length}<dl class="attendance-totals">{#each page.totals as total}<div><dt>{total.label}</dt><dd>{total.value}</dd></div>{/each}</dl>{/if}
  {#each page.days as day}
    <section class="student-record-section attendance-day" aria-label={date(day.date)}>
      <h2>{date(day.date)}</h2>
      {#if day.reason}<p class="attendance-reason">{day.reason}</p>{/if}
      {#if day.note}<p class="attendance-note">{day.note}</p>{/if}
      {#if day.periods.length}<ul class="attendance-periods">{#each day.periods as period}<li>
        <span class="attendance-period">{period.period ? `Period ${period.period}` : 'Period not provided'}</span>
        <span class="attendance-course"><strong>{period.course || 'Course not provided'}</strong>{#if period.teacher}<small>{period.teacher}</small>{/if}</span>
        <span class="attendance-status"><strong>{period.status || 'Status not provided'}</strong>{#if period.reason}<small>{period.reason}</small>{/if}</span>
      </li>{/each}</ul>
      {:else if !day.reason && !day.note}<p class="records-intro">No period details were provided.</p>{/if}
    </section>
  {:else}<p class="records-empty">No attendance records were returned by your district.</p>{/each}
{/if}
