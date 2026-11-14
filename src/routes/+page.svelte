<script lang="ts">
  import { onMount, untrack, tick } from 'svelte';
  import GradeSummary from '$lib/GradeSummary.svelte';
  import StudentRecords from '$lib/StudentRecords.svelte';
  import { readRecords, type RecordPage, type SubjectDetails } from '$lib/records';
  import { requestPortal, RequestFailure } from '$lib/portal-request';
  import {
    readLocation,
    courseLocation,
    scoreChange,
  } from '$lib/workspace';
  let { data: sessionData }: { data: { authenticated: boolean; signInError?: string; retrySavedSignIn?: boolean } } = $props();
  let authenticated = $state(untrack(() => sessionData.authenticated));
  import Icon from '$lib/Icon.svelte';
  import Trend from '$lib/Trend.svelte';
  import {
    calculate,
    letter,
    percentage,
    trend,
    type Course,
    type GradeData,
    type EventItem,
    type ScheduleData,
  } from '$lib/model';
  import {
    grades,
    profile,
    events,
    schedule as readSchedule,
  } from '$lib/portal-data';
  import './app.css';
  import './monochrome.css';
  import './login.css';
  import './workspace.css';
  const navigation = [
    { id: 'grades', label: 'Gradebook', icon: 'book' },
    { id: 'schedule', label: 'Schedule', icon: 'calendar' },
    { id: 'attendance', label: 'Attendance', icon: 'check' },
    { id: 'history', label: 'Course History', icon: 'history' },
    { id: 'student', label: 'Student Info', icon: 'person' },
    { id: 'mail', label: 'Inbox', icon: 'mail' },
    { id: 'documents', label: 'Documents', icon: 'file' },
  ];
  const loginDetails: Record<string, string> = {
    grades: 'Courses, assignments, and current grades',
    schedule: 'Classes, rooms, and terms',
    attendance: 'Absences and period status',
    history: 'Marks and credits by year',
    student: 'School and contact fields',
    mail: 'School messages, newest first',
    documents: 'File listings and downloads',
  };
  let tab = $state('grades'),
    data = $state<GradeData>({ courses: [], terms: [], currentTerm: 0 }),
    person = $state({ name: 'Student', school: 'Anoka-Hennepin', grade: '' }),
    busy = $state(untrack(() => sessionData.authenticated)),
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
    rememberSignIn = $state(false),
    loginBusy = $state(false),
    loginError = $state(untrack(() => sessionData.signInError ?? '')),
    hypothetical = $state(false);
  let edits = $state<Record<string, Course>>({}),
    resourceData = $state<Record<string, EventItem[]>>({}),
    schedule = $state<ScheduleData>({ terms: [], currentTerm: 0 });
  let generation = 0;
  const resourceLoads = new Map<string, Promise<void>>();
  const subjectCache = new Map<string, SubjectDetails>();
  let subjectPreload: Promise<void> | null = null;
  let recordPages = $state<Record<string, RecordPage>>({});
  const recordResources = ['student', 'history', 'attendance'];
  const remoteResources = ['schedule', 'mail', 'documents', ...recordResources];
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
  const categoryOptions = $derived(
    activeCourse
      ? [
          ...new Set(
            [
              ...activeCourse.categories.map((c) => c.name),
              ...activeCourse.assignments.map((a) => a.category),
            ].filter(Boolean),
          ),
        ]
      : [],
  );
  const scenarioAnnouncement = $derived(
    hypothetical
      ? 'Hypothetical estimate: ' +
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
  const recentAssignments = $derived(
    data.courses
      .flatMap((c) =>
        c.assignments
          .map((a) => ({ ...a, course: c })),
      )
      .toSorted(
        (a, b) => (Date.parse(b.due) || 0) - (Date.parse(a.due) || 0),
      )
      .slice(0, 8),
  );
  const selectedScheduleTerm = $derived(
    schedule.terms.find((term) => term.id === schedule.currentTerm) ??
      schedule.terms[0],
  );
  const scheduleRecords: EventItem[] = $derived(
    (selectedScheduleTerm?.classes ?? []).map((course) => ({
      title: course.title,
      detail: [course.teacher, course.room ? `Room ${course.room}` : '']
        .filter(Boolean)
        .join(' · '),
      date: [
        course.period ? `Period ${course.period}` : '',
        course.meetingDays ?? '',
      ]
        .filter(Boolean)
        .join(' · '),
    })),
  );
  const shownRecords = $derived(
    tab === 'schedule' ? scheduleRecords : (resourceData[tab] ?? []),
  );
  const dateLabel = (value: string) => {
    const d = new Date(value);
    return Number.isNaN(d.getTime())
      ? value
      : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };
  const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
  async function api(
    body: Record<string, unknown>,
    background = false,
  ): Promise<Record<string, unknown>> {
    try {
      return await requestPortal(body);
    } catch (e) {
      if (
        e instanceof RequestFailure &&
        e.status === 401 &&
        body.action !== 'login' &&
        !background
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
    resourceLoads.clear();
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
        api({ action: 'read', resource: 'profile' }).catch(() => null),
      ]);
      if (version !== generation || !authenticated) return;
      data = grades(g.data);
      if (p) person = profile(p.data);
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
    if (remoteResources.includes(id) && !hasResource(id))
      await loadResource(id);
  }
  function hasResource(id: string) {
    if (recordResources.includes(id)) return !!recordPages[id];
    return id === 'schedule' ? schedule.terms.length > 0 : !!resourceData[id];
  }
  async function loadHistorySubject(
    id: string,
    background = false,
  ): Promise<SubjectDetails> {
    const cached = subjectCache.get(id);
    if (cached) return cached;
    const version = generation;
    const response = await api(
      { action: 'read', resource: 'history-subject', subject: id },
      background,
    );
    if (version !== generation || !authenticated) throw new Error('Your workspace changed. Open the subject again.');
    const details = response.data as SubjectDetails;
    subjectCache.set(id, details);
    return details;
  }
  function preloadHistorySubjects() {
    const version = generation;
    const page = recordPages.history;
    if (subjectPreload || page?.kind !== 'history') return;
    subjectPreload = (async () => {
      try {
        for (const requirement of page.requirements) {
          if (!requirement.id || !authenticated || version !== generation)
            return;
          if (!subjectCache.has(requirement.id))
            await loadHistorySubject(requirement.id, true).catch(() => {});
        }
      } finally {
        subjectPreload = null;
      }
    })();
  }
  function loadResource(
    id: string,
    mode: 'foreground' | 'background' = 'foreground',
  ): Promise<void> {
    const running = resourceLoads.get(id);
    if (running) {
      if (mode === 'background') return running;
      busy = true;
      return running.finally(() => (busy = false));
    }
    const task = fetchResource(id, mode).finally(() => {
      if (resourceLoads.get(id) === task) resourceLoads.delete(id);
    });
    resourceLoads.set(id, task);
    return task;
  }
  async function fetchResource(
    id: string,
    mode: 'foreground' | 'background',
  ): Promise<void> {
    const version = generation;
    const foreground = mode === 'foreground';
    if (foreground) {
      busy = true;
      error = '';
      retryAction = null;
    }
    try {
      const res = await api(
        { action: 'read', resource: id },
        !foreground,
      );
      if (version !== generation || !authenticated) return;
      if (recordResources.includes(id)) {
        recordPages = { ...recordPages, [id]: readRecords(id, res.data) };
      } else if (id === 'schedule') {
        const previous = schedule.currentTerm;
        const next = readSchedule(res.data);
        schedule = next.terms.some((term) => term.id === previous)
          ? { ...next, currentTerm: previous }
          : next;
      } else {
        resourceData = { ...resourceData, [id]: events(res.data, id) };
      }
      refreshTimes = { ...refreshTimes, [id]: Date.now() };
      if (id === 'history') {
        subjectCache.clear();
        preloadHistorySubjects();
      }
    } catch (e) {
      if (foreground && version === generation && tab === id) {
        error =
          e instanceof Error ? e.message : 'Could not load this information.';
        retryAction = () => loadResource(id);
      }
    } finally {
      if (foreground && version === generation) busy = false;
    }
  }
  function preloadWorkspace() {
    const first =
      remoteResources.includes(tab) && !hasResource(tab)
        ? loadResource(tab)
        : Promise.resolve();
    return first
      .then(() =>
        Promise.allSettled(
          remoteResources
            .filter((id) => !hasResource(id))
            .map((id) => loadResource(id, 'background')),
        ),
      )
      .then(() => preloadHistorySubjects());
  }
  function openCourse(course: Course) {
    writeLocation(courseLocation(course.id));
    selected = course.id;
    tab = 'grades';
    hypothetical = false;
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
    key: 'earned' | 'possible' | 'title' | 'category',
    value: string,
  ) {
    if (!activeCourse) return;
    const course = clone(activeCourse);
    course.assignments = course.assignments.map((a) =>
      a.id === id
        ? {
            ...a,
            [key]:
              key === 'title' || key === 'category'
                ? value
                : value === '' && key === 'earned'
                  ? null
                  : Math.max(0, Number(value) || 0),
            ...(key === 'possible'
              ? { emptyPossible: value === '' }
              : {}),
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
    course.assignments.unshift({
      id: crypto.randomUUID(),
      title: 'Hypothetical assignment',
      category: course.categories[0]?.name ?? 'Practice',
      earned: null,
      possible: 0,
      due: new Date().toISOString().slice(0, 10),
      hypothetical: true,
      emptyPossible: true,
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
      await api({ action: 'login', username, password, remember: rememberSignIn });
      password = '';
      showPassword = false;
      authenticated = true;
      data = { courses: [], terms: [], currentTerm: 0 };
      person = { name: 'Student', school: 'Your school', grade: '' };
      resourceData = {};
      recordPages = {};
      schedule = { terms: [], currentTerm: 0 };
      tab = 'grades';
      writeLocation('#grades');
      await load();
      void preloadWorkspace();
    } catch (e) {
      loginError = e instanceof Error ? e.message : 'Unable to sign in.';
    } finally {
      loginBusy = false;
    }
  }
  let downloading = $state<Record<string, boolean>>({});
  let downloadErrors = $state<Record<string, string>>({});
  const downloadKey = (id: string, messageId?: string) =>
    messageId ? 'mail:' + messageId + ':' + id : id;
  async function downloadFile(
    item: Pick<EventItem, 'id' | 'filename'>,
    messageId?: string,
  ) {
    if (!item.id || downloading[downloadKey(item.id, messageId)]) return;
    const id = item.id,
      key = downloadKey(item.id, messageId),
      version = generation;
    downloading = { ...downloading, [key]: true };
    downloadErrors = { ...downloadErrors, [key]: '' };
    try {
      const response = await fetch('/api/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id,
          ...(messageId ? { kind: 'mail', messageId } : {}),
        }),
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
          [key]: e instanceof Error ? e.message : 'Download failed. Try again.',
        };
    } finally {
      if (version === generation)
        downloading = { ...downloading, [key]: false };
    }
  }
  function clearWorkspace() {
    downloading = {};
    downloadErrors = {};
    generation++;
    data = { courses: [], terms: [], currentTerm: 0 };
    person = { name: 'Student', school: 'Anoka-Hennepin', grade: '' };
    resourceData = {};
    recordPages = {};
    schedule = { terms: [], currentTerm: 0 };
    edits = {};
    selected = null;
    password = '';
    lastRefresh = null;
    refreshTimes = {};
    retryAction = null;
    busy = false;
    resourceLoads.clear();
    subjectCache.clear();
    subjectPreload = null;
  }
  async function logout() {
    let message = '';
    try {
      await api({ action: 'logout' });
    } catch (e) {
      message = e instanceof Error ? e.message : 'Could not fully sign out. Try again.';
    }
    // The server deletes cookies even when cleanup partially fails.
    authenticated = false;
    clearWorkspace();
    rememberSignIn = false;
    error = '';
    loginError = message;
  }
  async function changeTerm(value: string) {
    edits = {};
    selected = null;
    hypothetical = false;
    writeLocation('#grades');
    await load(Number(value));
  }
  function changeScheduleTerm(value: string) {
    schedule = { ...schedule, currentTerm: Number(value) };
    notice = '';
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
      if (remoteResources.includes(tab) && !hasResource(tab))
        void loadResource(tab);
    };
    window.addEventListener('popstate', back);
    const returned = (event: PageTransitionEvent) => {
      if (event.persisted && authenticated && !busy) void load();
    };
    window.addEventListener('pageshow', returned);
    if (authenticated)
      void load().then(() => {
        void preloadWorkspace();
      });
    return () => {
      mq.removeEventListener('change', resize);
      window.removeEventListener('popstate', back);
      window.removeEventListener('pageshow', returned);
    };
  });
</script>

<svelte:head
  ><title>Schoolity · Student dashboard for Anoka-Hennepin</title><meta
    name="description"
    content="Sign in with your StudentVUE account to open your gradebook, schedule, attendance, and school records. Schoolity never changes what the district has on file."
  /><meta name="page-type" content="software" /><meta
    name="site-kind"
    content="software"
  /><meta
    property="og:title"
    content="Schoolity · Student dashboard for Anoka-Hennepin"
  /><meta
    property="og:description"
    content="Sign in with your StudentVUE account to open your gradebook, schedule, attendance, and school records."
  /><meta property="og:type" content="website" /><meta
    name="twitter:card"
    content="summary"
  /><link rel="icon" href="/favicon.svg" type="image/svg+xml" /></svelte:head
>
<svelte:window
  onkeydown={(e) => {
    if (e.key === 'Escape') {
      privacyOpen = false;
      closeMenu();
    }
  }}
/>

<div class:dark class:workspace={authenticated} class="app-shell">
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
        href="#grades"
        class="brand"
        onclick={(e) => {
          e.preventDefault();
          void navigate('grades');
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
                  differ. Hypothetical changes stay in Schoolity.
                </p>
              </details>
            </div>
            <div class="large-trend">
              <Trend
                values={trend(activeCourse)}
                dates={activeCourse.assignments
                  .filter((a) => a.earned !== null && !a.excluded && !a.emptyPossible)
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
              <h2>Hypothetical</h2>
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
                  ><Icon name="plus" size={16} /> Add hypothetical</button
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
                          >Hypothetical</span
                        >{/if}{#if a.excluded}<small
                          >Excluded from calculation</small
                        >{/if}</td
                    ><td data-label="Category"
                      >{#if hypothetical}<select
                          class="category-select"
                          aria-label={`Category for ${a.title}`}
                          value={a.category}
                          onchange={(e) =>
                            editAssignment(
                              a.id,
                              'category',
                              e.currentTarget.value,
                            )}
                          >{#each categoryOptions as category}<option
                              value={category}>{category}</option
                            >{/each}</select
                        >{:else}<span class="subtle-tag">{a.category}</span
                        >{/if}</td
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
                            value={a.emptyPossible ? '' : a.possible}
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
                      >{#if a.earned === null || a.emptyPossible}<span class="pending"
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
        {:else if tab === 'grades'}
          <div class="page-heading">
            <div>
              <h1>
                Gradebook
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
          </section>
          <div class="content-columns">
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
                      <span class="subject-icon"
                        ><Icon name="book" size={22} /></span
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
            <section class="recent-assignments" aria-labelledby="recent-assignments-title">
              <h2 id="recent-assignments-title">Recent assignments</h2>
              <p class="recent-assignments-note">Latest due dates in this reporting period</p>
              <ul class="recent-assignment-list">
                {#each recentAssignments as assignment}
                  <li>
                    <button class="recent-assignment" onclick={() => openCourse(assignment.course)}>
                      <span class="recent-assignment-title">{assignment.title || 'Untitled assignment'}</span>
                      <span class="recent-assignment-course">{assignment.course.name}</span>
                      <span class="recent-assignment-meta">
                        <span>{assignment.due ? dateLabel(assignment.due) : 'No due date'}</span>
                        <span class="recent-assignment-score">{assignment.excluded
                          ? 'Not for grading'
                          : assignment.earned === null
                            ? 'Not graded'
                            : `${assignment.earned} / ${assignment.possible}`}</span>
                      </span>
                    </button>
                  </li>
                {:else}
                  <li class="recent-assignments-empty">{busy ? 'Loading assignments…' : 'No assignments in this reporting period.'}</li>
                {/each}
              </ul>
            </section>
          </div>
        {:else if recordResources.includes(tab)}
          <div class="page-heading">
            <h1>{navigation.find((item) => item.id === tab)?.label}</h1>
            <button class="refresh-button" disabled={busy} onclick={() => loadResource(tab)}>↻ Refresh</button>
          </div>
          {#if refreshTimes[tab]}<p class="resource-freshness">Last updated {new Date(refreshTimes[tab]).toLocaleTimeString([], {hour:'numeric',minute:'2-digit'})}</p>{/if}
          {#if recordPages[tab]}
            {#key recordPages[tab]}<StudentRecords page={recordPages[tab]} loadSubject={loadHistorySubject} />{/key}
          {:else if !busy && !error}<p class="records-empty">No information has been loaded. <button class="text-button" onclick={() => loadResource(tab)}>Load {navigation.find((item) => item.id === tab)?.label}</button></p>{/if}
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
          {#if tab === 'schedule' && schedule.terms.length}
            <div class="term-line">
              <span class="green-dot"></span><select
                aria-label="Schedule term"
                value={schedule.currentTerm}
                onchange={(e) => changeScheduleTerm(e.currentTarget.value)}
                >{#each schedule.terms as term}<option value={term.id}
                    >{term.name}</option
                  >{/each}</select
              ><span
                >{selectedScheduleTerm?.classes.length ?? 0} classes</span
              >
            </div>
          {/if}
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
                      {#if item.attachments?.length}<section
                          class="mail-attachments"
                          aria-label="Message attachments"
                        >
                          <h3>Attachments</h3>
                          <ul>
                            {#each item.attachments as attachment}<li>
                                <span class="attachment-name"
                                  >{attachment.filename}</span
                                ><button
                                  class="primary small"
                                  aria-label={'Download ' + attachment.filename}
                                  disabled={!item.id ||
                                    !attachment.id ||
                                    downloading[
                                      downloadKey(attachment.id, item.id)
                                    ]}
                                  onclick={() =>
                                    downloadFile(attachment, item.id)}
                                  >{downloading[
                                    downloadKey(attachment.id, item.id)
                                  ]
                                    ? 'Downloading…'
                                    : !item.id || !attachment.id
                                      ? 'Unavailable'
                                      : 'Download'}</button
                                >
                                {#if downloadErrors[downloadKey(attachment.id, item.id)]}<p
                                    class="document-error"
                                    role="alert"
                                  >
                                    {downloadErrors[
                                      downloadKey(attachment.id, item.id)
                                    ]}
                                  </p>{/if}
                              </li>{/each}
                          </ul>
                        </section>{/if}
                    </div>
                  </details>{/key}{:else if tab === 'documents'}<button
                  class="record-card document-card"
                  disabled={!item.id || downloading[item.id]}
                  aria-label={'Download ' + item.title}
                  aria-busy={!!item.id && !!downloading[item.id]}
                  onclick={() => downloadFile(item)}
                >
                  <span class="record-icon"><Icon name="file" size={18} /></span
                  ><span class="document-copy"
                    ><small>{item.date}</small><strong>{item.title}</strong
                    ><span>{item.detail}</span></span
                  >
                  {#if !item.id || downloading[item.id]}<span
                      class="document-status"
                      role="status"
                      >{item.id ? 'Downloading…' : 'Unavailable'}</span
                    >{/if}
                </button>{#if item.id && downloadErrors[item.id]}<p
                    class="document-error"
                    role="alert"
                  >
                    {downloadErrors[item.id]}
                  </p>{/if}{:else}<article class="record-card">
                  <span class="record-icon"
                    ><Icon
                      name={tab === 'schedule'
                        ? 'clock'
                        : tab === 'mail'
                          ? 'mail'
                          : 'file'}
                      size={18}
                    /></span
                  >
                  <div>
                    <small>{item.date}</small>
                    <h3>{item.title}</h3>
                    <p>{item.detail}</p>
                  </div>
                </article>{/if}{/each}{#if !shownRecords.length && !busy}<div
                class="empty-state"
              >
                <Icon
                  name={navigation.find((n) => n.id === tab)?.icon}
                  size={36}
                />
                {#if tab === 'schedule'}
                  <h2>No classes to show</h2>
                  <p>
                    {schedule.terms.length
                      ? 'No classes were returned for this term. Try another term or refresh.'
                      : 'No schedule was returned. Try refreshing.'}
                  </p>
                {:else}
                  <h2>No records to show</h2>
                  <p>
                    No records returned, or this district format isn’t supported
                    yet.
                  </p>
                {/if}
              </div>{/if}
          </section>
          {#if tab === 'mail'}<p class="calculation-note">
              Latest 50 messages.
            </p>{/if}
        {/if}
      </main>
    </div>
  {/if}
  {#if !authenticated}
    <main class="login-page" inert={privacyOpen} data-enter>
      <a class="skip-link" href="#login-form">Skip to sign-in form</a>
      <div class="login-shell">
        <div class="login-primary">
          <div class="login-topbar">
            <div class="login-brand" aria-label="Schoolity">
              <span class="login-mark" aria-hidden="true">S</span
              ><span class="login-wordmark">Schoolity</span>
            </div>
            <div class="login-meta">
              <span class="login-district"
                ><span class="district-dot" aria-hidden="true"></span
                >Anoka-Hennepin Schools</span
              ><button
                class="login-privacy"
                onclick={() => (privacyOpen = true)}
                ><Icon name="shield" size={13} /><span>Privacy</span></button
              >
            </div>
          </div>

          <div class="login-hero">
            <p class="login-eyebrow" data-rise style="--i: 0">
              <span class="eyebrow-dot" aria-hidden="true"></span>Grades,
              schedule, and records
            </p>
            <h1 id="login-title" data-rise style="--i: 1">
              The Anoka-Hennepin student dashboard.
            </h1>
            <p class="login-deck" data-rise style="--i: 2">
              Sign in with your StudentVUE account to open your gradebook,
              schedule, attendance, and school records. Schoolity never changes
              what the district has on file.
            </p>

            <section
              class="login-form-panel"
              id="login-form"
              aria-labelledby="signin-title"
              tabindex="-1"
              data-rise
              style="--i: 3"
            >
              <div class="login-form-head">
                <h2 id="signin-title">Sign in</h2>
                <span>StudentVUE</span>
              </div>
              <form onsubmit={login}>
                <label class="field" for="school-username">
                  <span>Username</span>
                  <input
                    id="school-username"
                    required
                    bind:value={username}
                    autocomplete="username"
                    spellcheck="false"
                  />
                </label>
                <div class="field">
                  <label for="school-password">Password</label>
                  <div class="password-control">
                    <input
                      id="school-password"
                      required
                      type={showPassword ? 'text' : 'password'}
                      bind:value={password}
                      autocomplete="current-password"
                    /><button
                      class="password-reveal"
                      type="button"
                      aria-controls="school-password"
                      aria-pressed={showPassword}
                      onclick={() => (showPassword = !showPassword)}
                      >{showPassword ? 'Hide' : 'Show'}<span class="sr-only">
                        password</span
                      ></button
                    >
                  </div>
                </div>
                <div class="remember-block">
                  <label class="remember-sign-in">
                    <input
                      type="checkbox"
                      bind:checked={rememberSignIn}
                      aria-describedby="remember-hint"
                    />
                    <span>Keep me signed in for 30 days</span>
                  </label>
                  <p class="remember-hint" id="remember-hint">
                    Stores an encrypted copy of your school login on Schoolity's
                    server. Signing out removes it.
                  </p>
                </div>
                {#if loginError}<div class="form-error" role="alert">
                    {loginError}
                  </div>{/if}
                <button class="primary login-submit" type="submit" disabled={loginBusy}
                  ><span>{loginBusy ? 'Signing in…' : 'Sign in'}</span><span
                    class="submit-arrow"
                    aria-hidden="true"><Icon name="arrow" size={15} /></span
                  ></button
                >
              </form>
              {#if sessionData.retrySavedSignIn}<button
                  class="login-text-button"
                  onclick={() => location.reload()}>Retry saved sign-in</button
                >{/if}
            </section>
          </div>

          <footer class="login-footer">
            <p>
              Independent student project. Not affiliated with or endorsed by
              Anoka-Hennepin Schools or Edupoint.
            </p>
            <p class="login-credit">
              Inter &amp; Inter Tight · SIL Open Font License
            </p>
          </footer>
        </div>

        <aside class="login-index" aria-labelledby="index-title">
          <div class="index-head" data-rise style="--i: 2">
            <h2 id="index-title">Inside the workspace</h2>
            <span>07 sections</span>
          </div>
          <ol data-rise style="--i: 3">
            {#each navigation as item}
              <li>
                <span class="index-icon"><Icon name={item.icon} size={17} /></span>
                <span class="index-name">{item.label}</span>
                <span class="index-detail">{loginDetails[item.id]}</span>
              </li>
            {/each}
          </ol>
          <div class="index-note" data-rise style="--i: 4">
            <span class="index-note-icon" aria-hidden="true"
              ><Icon name="shield" size={16} /></span
            >
            <div class="index-note-copy">
              <p class="index-note-title">Read-only by design.</p>
              <p>
                Schoolity reads the record your district already keeps. Grade
                estimates come from your assignments; district-reported grades
                stay separate.
              </p>
            </div>
          </div>
        </aside>
      </div>
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
          Saved sign-in keeps an encrypted copy of your school login on
          Schoolity's server for up to 30 days. Signing out removes it.
        </p>
        <p>Schoolity is independent of your district and Edupoint.</p>
        <details class="privacy-details">
          <summary>Connection details</summary>
          <h3>When you connect</h3>
          <p>
            Your username and password pass through this app's server to
            sign in to your district. Schoolity holds the resulting access token
            in memory locally or in a shared store on Vercel until the district
            session expires (up to 30 days). Your browser receives an HTTP-only
            session cookie. If you choose “Keep me signed in”, the server stores
            your username and password encrypted for up to 30 days so an expired
            school session can renew automatically. A separate HTTP-only cookie
            identifies that saved sign-in. Your password is never stored in
            browser storage. Signing out deletes the saved login and ends every
            session linked to it.
          </p>
          <h3>Where your information lives</h3>
          <p>
            Grades and other school records are held in this page's memory. API
            responses are marked no-store. The only preference saved in local
            storage is the color theme. Hosting and session-store operators can
            access data passing through its server, including decrypting saved
            sign-ins if they control the encryption key.
          </p>
          <h3>About this version</h3>
          <p>
            Login is required to access your school information. The district
            feature coverage is still being verified across district responses.
            Grade estimates may differ from district rules. This first version
            includes gradebook, calculator, schedule, student info, course history,
            attendance, inbox, and document-list
            adapters, and document downloads.
          </p>
        </details>
        <button class="primary" onclick={() => (privacyOpen = false)}
          >Done</button
        >
      </div>
    </div>{/if}
</div>
