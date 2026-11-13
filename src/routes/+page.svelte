<script lang="ts">
  import { onMount, untrack, tick } from 'svelte';
  import GradeSummary from '$lib/GradeSummary.svelte';
  import { requestPortal, RequestFailure } from '$lib/portal-request';
  import {
    readLocation,
    courseLocation,
    targetExplanation,
    scoreChange,
  } from '$lib/workspace';
  let { data: sessionData }: { data: { authenticated: boolean } } = $props();
  let authenticated = $state(untrack(() => sessionData.authenticated));
  import Icon from '$lib/Icon.svelte';
  import Trend from '$lib/Trend.svelte';
  import {
    calculate,
    letter,
    percentage,
    targetScore,
    trend,
    type Course,
    type GradeData,
    type EventItem,
  } from '$lib/model';
  import { grades, profile, events } from '$lib/portal-data';
  import './app.css';
  import './monochrome.css';
  const navigation = [
    { id: 'overview', label: 'Overview', icon: 'grid' },
    { id: 'grades', label: 'Gradebook', icon: 'book' },
    { id: 'schedule', label: 'Schedule', icon: 'calendar' },
    { id: 'mail', label: 'Inbox', icon: 'mail' },
    { id: 'documents', label: 'Documents', icon: 'file' },
  ];
  let tab = $state('overview'),
    data = $state<GradeData>({ courses: [], terms: [], currentTerm: 0 }),
    person = $state({ name: 'Student', school: 'Anoka-Hennepin', grade: '' }),
    busy = $state(false),
    error = $state(''),
    notice = $state('');
  let selected = $state<string | null>(null),
    mobileMenu = $state(false),
    privacyOpen = $state(false),
    dark = $state(false);
  let isMobile = $state(false),
    showPassword = $state(false);
  let lastRefresh = $state<number | null>(null),
    refreshTimes = $state<Record<string, number>>({}),
    retryAction = $state<null | (() => Promise<void>)>(null);
  let sidebar = $state<HTMLElement>(),
    mainContent = $state<HTMLElement>();
  let username = $state(''),
    password = $state(''),
    loginBusy = $state(false),
    loginError = $state(''),
    hypothetical = $state(false);
  let edits = $state<Record<string, Course>>({}),
    resourceData = $state<Record<string, EventItem[]>>({});
  let target = $state(90),
    targetPoints = $state(100),
    targetCategory = $state('');
  let generation = 0;
  const activeCourse = $derived(
    selected
      ? ((hypothetical ? edits[selected] : undefined) ??
          data.courses.find((c) => c.id === selected))
      : undefined,
  );
  const startingCourse = $derived(data.courses.find((c) => c.id === selected));
  const baselineEstimate = $derived(
    startingCourse ? calculate(startingCourse) : null,
  );
  const currentEstimate = $derived(
    activeCourse ? calculate(activeCourse) : null,
  );
  const scenarioAnnouncement = $derived(
    hypothetical
      ? 'What-if estimate: ' +
          percentage(currentEstimate) +
          '. ' +
          scoreChange(currentEstimate, baselineEstimate)
      : '',
  );
  const refreshLabel = $derived(
    lastRefresh
      ? 'Last updated ' +
          new Date(lastRefresh).toLocaleTimeString([], {
            hour: 'numeric',
            minute: '2-digit',
          })
      : 'Not yet loaded',
  );
  const scores = $derived(
    data.courses
      .map((c) => c.official ?? calculate(c))
      .filter((v): v is number => v !== null),
  );
  const average = $derived(
    scores.length ? scores.reduce((a, b) => a + b, 0) / scores.length : null,
  );
  const upcoming = $derived(
    data.courses
      .flatMap((c) =>
        c.assignments
          .filter((a) => a.earned === null && !a.excluded)
          .map((a) => ({ ...a, course: c.name, color: c.color })),
      )
      .toSorted(
        (a, b) => new Date(a.due).getTime() - new Date(b.due).getTime(),
      ),
  );
  const needed = $derived(
    activeCourse
      ? targetScore(
          activeCourse,
          targetCategory || activeCourse.categories[0]?.name || 'Practice',
          targetPoints,
          target,
        )
      : null,
  );
  const shownRecords = $derived(resourceData[tab] ?? []);
  const dateLabel = (value: string) => {
    const d = new Date(value);
    return Number.isNaN(d.getTime())
      ? value
      : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };
  const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
  async function api(
    body: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    try {
      return await requestPortal(body);
    } catch (e) {
      if (
        e instanceof RequestFailure &&
        e.status === 401 &&
        body.action !== 'login'
      ) {
        authenticated = false;
        clearWorkspace();
        loginError = e.message;
      }
      throw e;
    }
  }
  async function load(term?: number) {
    const version = ++generation;
    busy = true;
    error = '';
    retryAction = null;
    try {
      const [g, p] = await Promise.all([
        api({
          action: 'read',
          resource: 'grades',
          ...(term === undefined ? {} : { term }),
        }),
        api({ action: 'read', resource: 'profile' }).catch(() => ({
          data: {},
        })),
      ]);
      if (version !== generation || !authenticated) return;
      data = grades(g.data);
      person = profile(p.data);
      lastRefresh = Date.now();
      if (selected && !data.courses.some((c) => c.id === selected)) {
        selected = null;
        hypothetical = false;
        notice =
          'This course is not available in the selected reporting period.';
      }
      applyLocation();
    } catch (e) {
      if (version === generation) {
        error =
          e instanceof Error
            ? e.message
            : 'School data could not be loaded. Try again.';
        retryAction = () => load(term);
      }
    } finally {
      if (version === generation) busy = false;
    }
  }
  function closeMenu(restore = true) {
    mobileMenu = false;
    if (restore)
      void tick().then(() =>
        document.getElementById('navigation-toggle')?.focus(),
      );
  }
  function applyLocation() {
    const state = readLocation(location.hash);
    tab = state.section;
    selected = state.course;
    hypothetical = false;
    targetCategory =
      data.courses.find((c) => c.id === selected)?.categories[0]?.name ??
      'Practice';
    if (
      selected &&
      data.courses.length &&
      !data.courses.some((c) => c.id === selected)
    )
      selected = null;
  }
  function writeLocation(hash: string) {
    if (location.hash !== hash) history.pushState(null, '', hash);
  }
  async function navigate(id: string, record = true) {
    if (record) writeLocation('#' + id);
    tab = id;
    selected = null;
    hypothetical = false;
    closeMenu(false);
    notice = '';
    error = '';
    retryAction = null;
    window.scrollTo(0, 0);
    await tick();
    mainContent?.focus();
    if (['schedule', 'mail', 'documents'].includes(id) && !resourceData[id])
      await loadResource(id);
  }
  async function loadResource(id: string) {
    const version = generation;
    busy = true;
    error = '';
    retryAction = null;
    try {
      const res = await api({ action: 'read', resource: id });
      if (version !== generation || !authenticated) return;
      resourceData = { ...resourceData, [id]: events(res.data, id) };
      refreshTimes = { ...refreshTimes, [id]: Date.now() };
    } catch (e) {
      if (version === generation && tab === id) {
        error =
          e instanceof Error ? e.message : 'Could not load this information.';
        retryAction = () => loadResource(id);
      }
    } finally {
      if (version === generation) busy = false;
    }
  }
  function openCourse(course: Course) {
    writeLocation(courseLocation(course.id));
    selected = course.id;
    tab = 'grades';
    hypothetical = false;
    targetCategory = course.categories[0]?.name ?? 'Practice';
    closeMenu(false);
    window.scrollTo(0, 0);
    void tick().then(() => mainContent?.focus());
  }
  function removeAssignment(id: string) {
    if (!activeCourse) return;
    edits = {
      ...edits,
      [activeCourse.id]: {
        ...clone(activeCourse),
        assignments: activeCourse.assignments.filter(
          (a) => a.id !== id || !a.hypothetical,
        ),
      },
    };
  }
  function editAssignment(
    id: string,
    key: 'earned' | 'possible' | 'title',
    value: string,
  ) {
    if (!activeCourse) return;
    const course = clone(activeCourse);
    course.assignments = course.assignments.map((a) =>
      a.id === id
        ? {
            ...a,
            [key]:
              key === 'title'
                ? value
                : value === '' && key === 'earned'
                  ? null
                  : Math.max(0, Number(value) || 0),
          }
        : a,
    );
    edits = { ...edits, [course.id]: course };
  }
  function enableHypothetical() {
    hypothetical = !hypothetical;
    if (hypothetical && activeCourse && !edits[activeCourse.id])
      edits = { ...edits, [activeCourse.id]: clone(activeCourse) };
  }
  function addAssignment() {
    if (!activeCourse) return;
    const course = clone(activeCourse);
    course.assignments.push({
      id: crypto.randomUUID(),
      title: 'What-if assignment',
      category: targetCategory || course.categories[0]?.name || 'Practice',
      earned: 90,
      possible: 100,
      due: new Date().toISOString().slice(0, 10),
      hypothetical: true,
    });
    edits = { ...edits, [course.id]: course };
  }
  function resetEdits() {
    if (!selected) return;
    const next = { ...edits };
    delete next[selected];
    edits = next;
    hypothetical = false;
  }
  async function login(event: SubmitEvent) {
    event.preventDefault();
    loginError = '';
    loginBusy = true;
    try {
      await api({ action: 'login', username, password });
      password = '';
      showPassword = false;
      authenticated = true;
      data = { courses: [], terms: [], currentTerm: 0 };
      person = { name: 'Student', school: 'Your school', grade: '' };
      resourceData = {};
      tab = 'overview';
      await load();
    } catch (e) {
      loginError = e instanceof Error ? e.message : 'Unable to sign in.';
    } finally {
      loginBusy = false;
    }
  }
  let downloading = $state<Record<string, boolean>>({});
  let downloadErrors = $state<Record<string, string>>({});
  async function downloadFile(item: EventItem) {
    if (!item.id || downloading[item.id]) return;
    const id = item.id,
      version = generation;
    downloading = { ...downloading, [id]: true };
    downloadErrors = { ...downloadErrors, [id]: '' };
    try {
      const response = await fetch('/api/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
        cache: 'no-store',
      });
      if (!response.ok) {
        const answer = await response.json().catch(() => ({}));
        if (response.status === 401) {
          authenticated = false;
          clearWorkspace();
          loginError = answer.error || 'Sign in again to download.';
        }
        throw new Error(answer.error || 'Download failed. Try again.');
      }
      const blob = await response.blob();
      if (version !== generation || !authenticated) return;
      const disposition = response.headers.get('Content-Disposition') || '';
      const match = disposition.match(/filename\*=UTF-8''([^;]+)/i);
      const filename = match
        ? decodeURIComponent(match[1])
        : item.filename || 'document';
      const link = document.createElement('a'),
        url = URL.createObjectURL(blob);
      link.href = url;
      link.download = filename;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      if (version === generation)
        downloadErrors = {
          ...downloadErrors,
          [id]: e instanceof Error ? e.message : 'Download failed. Try again.',
        };
    } finally {
      if (version === generation) downloading = { ...downloading, [id]: false };
    }
  }
  function clearWorkspace() {
    downloading = {};
    downloadErrors = {};
    generation++;
    data = { courses: [], terms: [], currentTerm: 0 };
    person = { name: 'Student', school: 'Anoka-Hennepin', grade: '' };
    resourceData = {};
    edits = {};
    selected = null;
    password = '';
    lastRefresh = null;
    refreshTimes = {};
    retryAction = null;
    busy = false;
  }
  async function logout() {
    try {
      await api({ action: 'logout' });
      authenticated = false;
      clearWorkspace();
      loginError = '';
    } catch (e) {
      error = e instanceof Error ? e.message : 'Could not sign out. Try again.';
    }
  }
  async function changeTerm(value: string) {
    edits = {};
    selected = null;
    hypothetical = false;
    writeLocation('#grades');
    await load(Number(value));
  }
  function focusDialog(node: HTMLElement) {
    const previous = document.activeElement as HTMLElement | null;
    queueMicrotask(() =>
      node.querySelector<HTMLElement>('input,button')?.focus(),
    );
    const listener = (event: KeyboardEvent) => {
      if (event.key !== 'Tab') return;
      const controls = [
        ...node.querySelectorAll<HTMLElement>(
          'button:not(:disabled),input,select,[tabindex="0"]',
        ),
      ];
      const first = controls[0],
        last = controls.at(-1);
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };
    node.addEventListener('keydown', listener);
    return {
      destroy() {
        node.removeEventListener('keydown', listener);
        previous?.focus();
      },
    };
  }
  function toggleTheme() {
    dark = !dark;
    localStorage.setItem('schoolity_theme', dark ? 'dark' : 'light');
  }
  $effect(() => {
    if (!isMobile || !mobileMenu || !sidebar || privacyOpen) return;
    const panel = sidebar;
    const before = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    void tick().then(() =>
      sidebar?.querySelector<HTMLElement>('button,a')?.focus(),
    );
    const trap = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        closeMenu();
        return;
      }
      if (e.key !== 'Tab') return;
      const list = [
        ...panel.querySelectorAll<HTMLElement>('button,a[href],input,select'),
      ].filter((n) => n.getBoundingClientRect().width > 0);
      if (!list.length) return;
      const first = list[0],
        last = list.at(-1);
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last?.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', trap);
    return () => {
      document.removeEventListener('keydown', trap);
      document.body.style.overflow = overflow;
      if (before?.isConnected) before.focus();
    };
  });
  onMount(() => {
    dark = localStorage.getItem('schoolity_theme') === 'dark';
    const mq = window.matchMedia('(max-width:760px)');
    const resize = () => {
      isMobile = mq.matches;
      if (!mq.matches) mobileMenu = false;
    };
    resize();
    mq.addEventListener('change', resize);
    applyLocation();
    const back = () => {
      applyLocation();
      closeMenu(false);
      if (['schedule', 'mail', 'documents'].includes(tab) && !resourceData[tab])
        void loadResource(tab);
    };
    window.addEventListener('popstate', back);
    if (authenticated)
      void load().then(() => {
        if (['schedule', 'mail', 'documents'].includes(tab))
          void loadResource(tab);
      });
    return () => {
      mq.removeEventListener('change', resize);
      window.removeEventListener('popstate', back);
    };
  });
</script>

<svelte:head
  ><title>Schoolity · Your school day, in focus</title><meta
    name="description"
    content="A calmer school dashboard with a gradebook, what-if calculator, schedule, and your next steps."
  /></svelte:head
>
<svelte:window
  onkeydown={(e) => {
    if (e.key === 'Escape') {
      privacyOpen = false;
      closeMenu();
    }
  }}
/>

<div class:dark class="app-shell">
  {#if authenticated}
    <aside
      id="school-navigation"
      bind:this={sidebar}
      class:mobile-open={mobileMenu}
      inert={(isMobile && !mobileMenu) || privacyOpen}
      aria-hidden={isMobile && !mobileMenu}
    >
      <button
        class="mobile-nav-close icon-button"
        aria-label="Close navigation"
        onclick={() => closeMenu()}><Icon name="close" /></button
      >
      <a
        href="#overview"
        class="brand"
        onclick={(e) => {
          e.preventDefault();
          void navigate('overview');
        }}><span class="brand-symbol">S</span>Schoolity</a
      >
      <nav aria-label="Main navigation">
        {#each navigation as item}<button
            class:active={tab === item.id}
            aria-current={tab === item.id ? 'page' : undefined}
            onclick={() => navigate(item.id)}
            ><Icon name={item.icon} /><span>{item.label}</span></button
          >{/each}
      </nav>

      <div class="sidebar-bottom">
        <button class="privacy-link" onclick={() => (privacyOpen = true)}
          ><Icon name="shield" size={17} /> Privacy & connection</button
        >
        <div class="profile">
          <span class="avatar"
            >{person.name
              .split(' ')
              .map((s) => s[0])
              .slice(0, 2)
              .join('')}</span
          ><span
            ><strong>{person.name}</strong><small>Student account</small></span
          >
        </div>
        <button class="sign-out-button" onclick={logout}
          ><Icon name="logout" size={17} />Sign out</button
        >
      </div>
    </aside>
    {#if isMobile && mobileMenu}<button
        class="navigation-backdrop"
        aria-label="Close navigation"
        tabindex="-1"
        onclick={() => closeMenu()}
      ></button>{/if}
    <div class="main-shell" inert={(isMobile && mobileMenu) || privacyOpen}>
      <header>
        <div class="breadcrumb">
          <button
            class="icon-button mobile-toggle"
            id="navigation-toggle"
            aria-label="Open navigation"
            aria-expanded={mobileMenu}
            aria-controls="school-navigation"
            onclick={() => (mobileMenu ? closeMenu() : (mobileMenu = true))}
            ><Icon name="menu" /></button
          ><strong>{navigation.find((n) => n.id === tab)?.label}</strong>
        </div>
        <div class="header-actions">
          <button
            class="icon-button"
            aria-label="Toggle color theme"
            aria-pressed={dark}
            onclick={toggleTheme}><Icon name="sun" /></button
          >
        </div>
      </header>
      <main bind:this={mainContent} tabindex="-1" aria-label="School workspace">
        {#if error}<div class="alert" role="alert">
            <strong>School data could not be refreshed</strong>
            <p>{error}</p>
            <div class="inline-actions">
              {#if retryAction}<button
                  class="primary small"
                  disabled={busy}
                  onclick={() => retryAction?.()}>Retry</button
                >{/if}<button class="text-button" onclick={() => (error = '')}
                >Dismiss</button
              >
            </div>
          </div>{/if}
        {#if notice}<div class="notice" role="status">{notice}</div>{/if}
        {#if busy}<div class="loading" role="status">
            Loading school data…
          </div>{/if}
        {#if activeCourse}
          <button class="back-link" onclick={() => navigate('grades')}
            >← All courses</button
          >
          <div class="page-heading course-heading">
            <div>
              <h1>{activeCourse.name}</h1>
              <p>
                {activeCourse.teacher} · Period {activeCourse.period} · Room {activeCourse.room}
              </p>
            </div>
          </div>
          <section class="course-progress" aria-label="Grade history">
            <div class="progress-heading">
              {#if startingCourse}<GradeSummary
                  course={activeCourse}
                  starting={startingCourse}
                  scenario={hypothetical}
                />{/if}
              <details class="estimate-details">
                <summary>About estimates</summary>
                <p>
                  Calculated from scored assignments. School grading rules may
                  differ. What-if changes stay in Schoolity.
                </p>
              </details>
            </div>
            <div class="large-trend">
              <Trend
                values={trend(activeCourse)}
                dates={activeCourse.assignments
                  .filter((a) => a.earned !== null && !a.excluded)
                  .toSorted((a, b) => Date.parse(a.due) - Date.parse(b.due))
                  .map((a) => a.due)}
                large
              />
            </div>
          </section>
          <div
            class="sr-only"
            role="status"
            aria-live="polite"
            aria-atomic="true"
          >
            {scenarioAnnouncement}
          </div>
          <section class="what-if">
            <div>
              <h2>What-if</h2>
              <p>Local changes only.</p>
            </div>
            <button
              class:enabled={hypothetical}
              class="toggle-control"
              role="switch"
              aria-checked={hypothetical}
              aria-controls="assignment-table"
              onclick={enableHypothetical}><span></span>Edit scores</button
            >
          </section>
          {#if hypothetical}<section class="target-panel">
              <div>
                <h3>Target score</h3>
              </div>
              <label
                >Target grade (%)<input
                  type="number"
                  min="0"
                  max="120"
                  bind:value={target}
                /></label
              ><label
                >Points possible<input
                  type="number"
                  min="1"
                  bind:value={targetPoints}
                /></label
              ><label
                >Category<select bind:value={targetCategory}
                  >{#each activeCourse.categories.length ? activeCourse.categories : [{ name: 'Practice', weight: 0 }] as cat}<option
                      value={cat.name}>{cat.name}</option
                    >{/each}</select
                ></label
              >
              <div class="target-result" aria-live="polite" aria-atomic="true">
                <strong
                  >{needed === null
                    ? 'Estimate unavailable'
                    : needed <= 0
                      ? 'Already there'
                      : needed.toFixed(1) + ' / ' + targetPoints}</strong
                ><small>{targetExplanation(targetPoints, target, needed)}</small
                >
              </div>
            </section>{/if}
          <div class="section-heading">
            <h2>
              Assignments <span class="count"
                >{activeCourse.assignments.length}</span
              >
            </h2>
            {#if hypothetical}<div class="inline-actions">
                <button class="text-button" onclick={resetEdits}
                  >Reset changes</button
                ><button class="primary small" onclick={addAssignment}
                  ><Icon name="plus" size={16} /> Add what-if</button
                >
              </div>{/if}
          </div>
          <div class="table-wrap" id="assignment-table">
            <table>
              <caption class="sr-only"
                >Assignments, scores, and grades for {activeCourse.name}.
                Hypothetical inputs only change your local scenario.</caption
              >
              <thead
                ><tr
                  ><th>Assignment</th><th>Category</th><th>Due</th><th>Score</th
                  ><th>Grade</th>{#if hypothetical}<th
                      ><span class="sr-only">Scenario actions</span></th
                    >{/if}</tr
                ></thead
              ><tbody
                >{#each activeCourse.assignments as a}<tr
                    class:hypothetical-row={a.hypothetical}
                    ><td data-label="Assignment"
                      >{#if hypothetical}<input
                          aria-label={`Assignment title for ${a.title}`}
                          class="title-input"
                          value={a.title}
                          oninput={(e) =>
                            editAssignment(
                              a.id,
                              'title',
                              e.currentTarget.value,
                            )}
                        />{:else}<strong>{a.title}</strong
                        >{/if}{#if a.hypothetical}<span class="tiny-tag"
                          >What-if</span
                        >{/if}{#if a.excluded}<small
                          >Excluded from calculation</small
                        >{/if}</td
                    ><td data-label="Category"
                      ><span class="subtle-tag">{a.category}</span></td
                    ><td data-label="Due">{dateLabel(a.due)}</td><td
                      data-label="Score"
                      >{#if hypothetical}<div class="score-inputs">
                          <input
                            aria-label={`Points earned for ${a.title}`}
                            type="number"
                            min="0"
                            value={a.earned ?? ''}
                            placeholder="—"
                            oninput={(e) =>
                              editAssignment(
                                a.id,
                                'earned',
                                e.currentTarget.value,
                              )}
                          /><span>/</span><input
                            aria-label={`Points possible for ${a.title}`}
                            type="number"
                            min="0"
                            value={a.possible}
                            oninput={(e) =>
                              editAssignment(
                                a.id,
                                'possible',
                                e.currentTarget.value,
                              )}
                          />
                        </div>{:else}{a.earned === null ? '—' : a.earned}
                        <span class="muted">/ {a.possible}</span>{/if}</td
                    ><td data-label="Grade"
                      >{#if a.earned === null}<span class="pending"
                          >Not graded</span
                        >{:else if a.possible > 0}<span class="grade-label"
                          >{percentage((a.earned / a.possible) * 100)}</span
                        >{:else}Extra credit{/if}</td
                    >{#if hypothetical}<td
                        >{#if a.hypothetical}<button
                            class="remove-assignment icon-button"
                            aria-label={'Remove ' + a.title}
                            onclick={() => removeAssignment(a.id)}
                            ><Icon name="close" size={16} /></button
                          >{/if}</td
                      >{/if}</tr
                  >{:else}<tr
                    ><td colspan={hypothetical ? 6 : 5}>No assignments yet.</td
                    ></tr
                  >{/each}</tbody
              >
            </table>
          </div>
        {:else if tab === 'overview' || tab === 'grades'}
          <div class="page-heading">
            <div>
              <h1>
                {tab === 'overview' ? 'Overview' : 'Gradebook'}
              </h1>
            </div>
            <button
              class="refresh-button"
              disabled={busy}
              onclick={() => void load()}>↻ Refresh</button
            >
          </div>
          <section class="stats-grid">
            <div class="stat-card">
              <span>Course average</span><strong>{percentage(average)}</strong
              ><small>Unweighted</small>
            </div>
            <div class="stat-card">
              <span>Courses</span><strong>{data.courses.length}</strong>
            </div>
            <div class="stat-card accent-stat">
              <span>Ungraded</span><strong>{upcoming.length}</strong>
            </div>
          </section>
          <div class="content-columns" class:gradebook-page={tab === 'grades'}>
            <div class="courses-column">
              <div class="section-heading">
                <div>
                  <h2>
                    Your courses <span class="count">{data.courses.length}</span
                    >
                  </h2>
                </div>
              </div>
              <div class="term-line">
                <span class="green-dot"></span><select
                  aria-label="Reporting period"
                  value={data.currentTerm}
                  onchange={(e) => changeTerm(e.currentTarget.value)}
                  >{#each data.terms as term}<option value={term.id}
                      >{term.name}</option
                    >{/each}</select
                ><span>{refreshLabel}</span>
              </div>
              <div class="course-grid">
                {#each data.courses as course}<button
                    class="course-card"
                    onclick={() => openCourse(course)}
                    ><div class="course-card-top">
                      <span
                        class="subject-icon"
                        style={`--subject:${course.color}`}
                        ><Icon
                          name={course.id === 'design' ? 'spark' : 'book'}
                          size={22}
                        /></span
                      >
                    </div>
                    <h3>{course.name}</h3>
                    <p>{course.teacher} <span>· Room {course.room}</span></p>
                    <div class="course-card-bottom">
                      <div>
                        <strong
                          >{percentage(
                            course.official ?? calculate(course),
                          )}</strong
                        ><span class="letter-grade"
                          >{letter(course.official ?? calculate(course))}</span
                        ><small
                          >{course.official === null
                            ? 'Calculated'
                            : 'District grade'}</small
                        >
                      </div>
                    </div></button
                  >{/each}
              </div>
              {#if !data.courses.length && !busy}<div class="empty-state">
                  <Icon name="search" size={32} />
                  <h3>No courses yet</h3>
                  <p>
                    No courses are available for this reporting period. Try
                    another period or refresh.
                  </p>
                </div>{/if}
            </div>
            <div class="right-column">
              <section class="up-next">
                <div class="section-heading">
                  <h2>Ungraded assignments</h2>
                  <Icon name="clock" size={17} />
                </div>

                {#each upcoming.slice(0, 4) as task}<button
                    class="upcoming-task"
                    onclick={() => {
                      const c = data.courses.find(
                        (c) => c.name === task.course,
                      );
                      if (c) openCourse(c);
                    }}
                    ><span
                      class="task-marker"
                      style={`background:${task.color}`}
                    ></span>
                    <div>
                      <strong>{task.title}</strong><small>{task.course}</small
                      ><span
                        >{dateLabel(task.due)} <i>·</i>
                        {task.possible} points</span
                      >
                    </div>
                    <Icon name="chevron" size={14} /></button
                  >{/each}{#if !upcoming.length}<p class="section-description">
                    No ungraded assignments.
                  </p>{/if}
              </section>
            </div>
          </div>
        {:else}
          <div class="page-heading">
            <div>
              <h1>
                {tab === 'schedule'
                  ? 'Schedule'
                  : tab === 'mail'
                    ? 'Inbox'
                    : 'Documents'}
              </h1>
            </div>
            <button
              class="refresh-button"
              disabled={busy}
              onclick={() => loadResource(tab)}>↻ Refresh</button
            >
          </div>
          {#if refreshTimes[tab]}<p class="resource-freshness">
              Last updated {new Date(refreshTimes[tab]).toLocaleTimeString([], {
                hour: 'numeric',
                minute: '2-digit',
              })}
            </p>{/if}
          <section class="records-list">
            {#each shownRecords as item}{#if tab === 'mail'}{#key item}<details
                    class="mail-message"
                  >
                    <summary
                      ><span class="mail-heading"
                        ><span>{item.title || 'Untitled message'}</span><span
                          class="mail-author"
                          >{item.author || 'Unknown sender'}</span
                        ></span
                      ><Icon name="chevron" size={16} /></summary
                    >
                    <div class="mail-content">
                      <small>{item.date}</small>
                      <p>{item.detail || 'No message content.'}</p>
                    </div>
                  </details>{/key}{:else}<article class="record-card">
                  <span class="record-icon"
                    ><Icon
                      name={tab === 'schedule'
                        ? 'clock'
                        : tab === 'mail'
                          ? 'mail'
                          : 'file'}
                      size={22}
                    /></span
                  >
                  <div>
                    <small>{item.date}</small>
                    <h3>{item.title}</h3>
                    <p>{item.detail}</p>
                  </div>
                  {#if tab === 'documents'}<div class="document-actions">
                      <button
                        class="primary small"
                        disabled={!item.id || downloading[item.id]}
                        onclick={() => downloadFile(item)}
                        >{item.id && downloading[item.id]
                          ? 'Downloading…'
                          : item.id
                            ? 'Download'
                            : 'Unavailable'}</button
                      >{#if item.id && downloadErrors[item.id]}<p
                          class="document-error"
                          role="alert"
                        >
                          {downloadErrors[item.id]}
                        </p>{/if}
                    </div>{/if}
                </article>{/if}{/each}{#if !resourceData[tab]?.length && !busy}<div
                class="empty-state"
              >
                <Icon
                  name={navigation.find((n) => n.id === tab)?.icon}
                  size={36}
                />
                <h2>No records to show</h2>
                <p>
                  No records returned, or this district format isn’t supported
                  yet.
                </p>
              </div>{/if}
          </section>
          <p class="calculation-note">
            {tab === 'mail'
              ? 'Latest 50 messages. Attachments unavailable.'
              : tab === 'documents'
                ? ''
                : 'Calendar sync unavailable.'}
          </p>
        {/if}
      </main>
    </div>
  {/if}
  {#if !authenticated}
    <main class="login-page" inert={privacyOpen}>
      <div class="login-brand">
        <span class="login-logo">S</span><strong>Schoolity</strong>
      </div>
      <section class="login-card" aria-labelledby="login-title">
        <h1 id="login-title">Sign in</h1>
        <form onsubmit={login}>
          <label
            >Username<input
              required
              bind:value={username}
              autocomplete="username"
              placeholder="StudentVUE username"
            /></label
          >
          <label for="school-password">Password</label>
          <div class="password-control">
            <input
              id="school-password"
              required
              type={showPassword ? 'text' : 'password'}
              bind:value={password}
              autocomplete="current-password"
              placeholder="StudentVUE password"
            /><button
              type="button"
              aria-controls="school-password"
              aria-pressed={showPassword}
              onclick={() => (showPassword = !showPassword)}
              >{showPassword ? 'Hide' : 'Show'}<span class="sr-only">
                password</span
              ></button
            >
          </div>
          {#if loginError}<div class="form-error" role="alert">
              {loginError}
            </div>{/if}
          <button class="primary" type="submit" disabled={loginBusy}
            >{loginBusy ? 'Signing in…' : 'Sign in'}<Icon
              name="arrow"
              size={16}
            /></button
          >
        </form>
        <button class="text-button" onclick={() => (privacyOpen = true)}
          >Privacy & connection</button
        >
      </section>
    </main>
  {/if}
  {#if privacyOpen}<div
      class="modal-backdrop"
      role="presentation"
      onclick={(e) => {
        if (e.target === e.currentTarget) privacyOpen = false;
      }}
    >
      <div
        use:focusDialog
        class="modal privacy-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="privacy-title"
        tabindex="-1"
      >
        <button
          class="modal-close icon-button"
          aria-label="Close privacy"
          onclick={() => (privacyOpen = false)}><Icon name="close" /></button
        ><Icon name="shield" size={32} />
        <h2 id="privacy-title">Privacy</h2>
        <p class="privacy-summary">
          Your password isn’t saved. Signing out clears this workspace.
        </p>
        <p>Schoolity is independent of your district and Edupoint.</p>
        <details class="privacy-details">
          <summary>Connection details</summary>
          <h3>When you connect</h3>
          <p>
            Your username and password pass through this app's server once to
            sign in to your district. Schoolity holds the resulting access token
            in memory locally or in a shared store on Vercel until the district
            session expires (up to 30 days). Your browser receives an HTTP-only
            session cookie. Your password is not saved in the browser or on the
            server.
          </p>
          <h3>Where your information lives</h3>
          <p>
            Grades and other school records are held in this page's memory. API
            responses are marked no-store. The only preference saved in local
            storage is the color theme. Hosting and session-store operators can
            access data passing through its server.
          </p>
          <h3>About this version</h3>
          <p>
            Login is required to access your school information. The district
            feature coverage is still being verified across district responses.
            Grade estimates may differ from district rules. This first version
            includes gradebook, calculator, schedule, inbox, and document-list
            adapters and document downloads; calendar sync is not yet available.
          </p>
        </details>
        <button class="primary" onclick={() => (privacyOpen = false)}
          >Done</button
        >
      </div>
    </div>{/if}
</div>
