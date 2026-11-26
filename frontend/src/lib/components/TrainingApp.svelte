<script lang="ts">
  import metadata from "../../../package.json";
  import { onMount, tick } from "svelte";
  import { goto, afterNavigate } from "$app/navigation";
  import { training } from "$lib/data";
  import { readDraft, writeDraft, listDrafts } from "$lib/domain/drafts";
  import Sheet from "./Sheet.svelte";
  import Stepper from "./Stepper.svelte";
  import Icon from "./Icon.svelte";
  import SetRow from "./SetRow.svelte";
  import {
    days,
    groups,
    title,
    primary,
    groupStyle,
    truth,
    list,
    dateValue,
    todayKey,
    plan,
    program,
    target,
    label,
    session,
    entries,
    formatReps,
    formatRir,
    estimate1Rm,
    weightForReps,
    repsForWeight,
    progression,
    exportPlan,
    normalizePlan,
    importTarget,
    validateVolume,
    api,
    download,
    clamp,
    type Row,
  } from "$lib/domain/training";
  let routeUrl = new URL("http://localhost/");
  afterNavigate(({ to }) => {
    routeUrl = to?.url || new URL(location.href);
    parseRoute();
    if (["/generate", "/import"].includes(routeUrl.pathname))
      void refreshAiAvailability();
  });
  let selected: { week: number; day: number } | null = null;
  let viz = "calendar";
  let activeSet = "";
  let parsedDay = "";
  let touchStart: { x: number; y: number } | null = null;
  let extra: Record<string, number> = {};
  let sheet: Row | null = null;
  let stack: Row[] = [];
  let busy = false;
  let conflicts: Row[] = [];
  let workflowReady = false;
  let workflowId = "";
  let tabId = "";
  let savedWorkflows: Row[] = [];
  let pendingJob: Row | null = null;
  let toast = "";
  let error = "";
  let dialogError = "";
  let pendingFocus: number | undefined;
  let review: Row | null = null;
  let job: Row | null = null;
  let jobBusy = false;
  let jobError = "";
  let jobStatus = "";
  let aiAvailable: boolean | null = null;
  let aiCheckPending = false;
  let aiCheckVersion = 0;
  let lastJob: { kind: string; input: Row } | null = null;
  let taskVersion = 0;
  let description = "";
  let experience = "intermediate";
  let goal = "mix";
  let sport = "";
  let numWeeks = 5;
  let trainingDays = 4;
  let basis = "";
  let basisMode = "inspiration";
  let importFile: HTMLInputElement;
  let restoreFile: HTMLInputElement;
  let pickerSearch = "";
  let pickerGroup = "chest";
  let customName = "";
  let pickerSelect: (e: Row) => void = () => {};
  let dragIndex = -1;
  let calcMode = "estimate";
  let formula = "epley";
  let calcWeight = 60;
  let calcReps = 8;
  let calcRir = 1;
  let calcOne = 100;
  let calcLift = 80;
  let updateReady = false;
  let worker: ServiceWorkerRegistration | undefined;
  $: tables = $training.tables;
  $: mesos = tables.mesocycles || [];
  $: meso =
    mesos.find((m: Row) => m.id === routeUrl.searchParams.get("meso")) ||
    mesos.find((m: Row) => truth(m.is_active)) ||
    null;
  $: today = todayKey(meso);
  $: effective = selected || today;
  $: week = effective?.week ?? 0;
  $: day = effective?.day ?? 0;
  $: items = meso && effective ? plan(tables, meso!.id, week, day) : [];
  $: group = primary(items);
  $: split = meso ? label(tables, meso!.id, day) : null;
  $: deloads = meso ? list(meso!.deload_weeks) : [];
  $: currentEntries =
    meso && effective ? entries(tables, meso!.id, week, day) : [];
  $: previousSets = previousSetIndex(
    tables.set_entries || [],
    meso && effective ? session(tables, meso.id, week, day)?.id : undefined,
  );
  $: view = routeUrl.pathname;
  $: conflicts = $training.conflicts;
  $: if ($training.ready && routeUrl) parseRoute();
  $: if (view !== "/log") activeSet = "";
  $: if (meso && selected && selected.week >= meso!.num_weeks) selected = null;
  $: calculation =
    calcMode === "estimate"
      ? `${estimate1Rm(calcWeight, calcReps, calcRir, formula).toFixed(1)} kg`
      : calcMode === "weight"
        ? `${(Math.round(weightForReps(calcOne, calcReps, calcRir, formula) / 2.5) * 2.5).toFixed(1)} kg`
        : `${repsForWeight(calcOne, calcLift, formula)} reps`;
  onMount(() => {
    restoreWorkflows();
    training.initialize().catch((e: unknown) => (error = String(e)));
    window.addEventListener("online", refreshAiAvailability);
    window.addEventListener("offline", markAiUnavailable);
    document.addEventListener("visibilitychange", checkVisibleAiAvailability);
    const aiRefreshTimer = window.setInterval(
      checkVisibleAiAvailability,
      15_000,
    );
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker
        .register("/sw.js", { type: "module" })
        .then((r) => {
          worker = r;
          updateReady = !!r.waiting;
          r.addEventListener("updatefound", () => {
            r.installing?.addEventListener("statechange", () => {
              if (r.waiting) updateReady = true;
            });
          });
        })
        .catch(() => {});
    }
    return () => {
      taskVersion++;
      aiCheckVersion++;
      window.removeEventListener("online", refreshAiAvailability);
      window.removeEventListener("offline", markAiUnavailable);
      document.removeEventListener(
        "visibilitychange",
        checkVisibleAiAvailability,
      );
      window.clearInterval(aiRefreshTimer);
    };
  });
  async function refreshAiAvailability() {
    if (aiCheckPending) return;
    aiCheckPending = true;
    const version = ++aiCheckVersion;
    try {
      const health = await api("health");
      if (version === aiCheckVersion) aiAvailable = health.aiAvailable === true;
    } catch {
      if (version === aiCheckVersion) aiAvailable = false;
    } finally {
      if (version === aiCheckVersion) aiCheckPending = false;
    }
  }
  function markAiUnavailable() {
    aiCheckVersion++;
    aiCheckPending = false;
    aiAvailable = false;
  }
  function checkVisibleAiAvailability() {
    if (
      document.visibilityState === "visible" &&
      navigator.onLine &&
      (view === "/generate" ||
        view === "/import" ||
        sheet?.kind === "switcher" ||
        sheet?.kind === "volume")
    ) {
      void refreshAiAvailability();
    }
  }
  function notify(s: string) {
    toast = s;
    window.clearTimeout(pendingFocus);
    pendingFocus = window.setTimeout(() => (toast = ""), 4500);
  }
  function open(s: Row) {
    if (s.kind === "switcher" || s.kind === "volume")
      void refreshAiAvailability();
    dialogError = "";
    stack = [];
    sheet = s;
  }
  function push(s: Row) {
    if (sheet) stack = [...stack, sheet];
    dialogError = "";
    sheet = s;
  }
  function close() {
    dialogError = "";
    sheet = stack.pop() || null;
    stack = [...stack];
  }
  async function run(fn: () => Promise<any>, message = "") {
    busy = true;
    dialogError = "";
    try {
      await fn();
      if (message) notify(message);
    } catch (e) {
      dialogError = String(e instanceof Error ? e.message : e);
      error = dialogError;
    } finally {
      busy = false;
    }
  }
  async function command(type: string, payload: Row) {
    return training.command(type, payload);
  }
  function routeFor(
    path: string,
    w = selected?.week,
    d = selected?.day,
    slot = "",
  ) {
    const u = new URL(path, location.origin);
    if (
      meso &&
      (routeUrl.searchParams.has("meso") ||
        (w !== undefined && d !== undefined))
    )
      u.searchParams.set("meso", meso.id);
    if (meso && w !== undefined && d !== undefined) {
      u.searchParams.set("week", String(w));
      u.searchParams.set("day", String(d));
      if (slot) u.searchParams.set("slot", slot);
    }
    return u.pathname + u.search;
  }
  function parseRoute() {
    if (!$training.ready) return;
    const w = routeUrl.searchParams.get("week"),
      d = routeUrl.searchParams.get("day"),
      m = routeUrl.searchParams.get("meso");
    if (w === null && d === null) {
      selected = null;
      return;
    }
    const mw = (tables.mesocycles || []).find((x: Row) => x.id === m) || meso;
    if (
      (m && !(tables.mesocycles || []).some((x: Row) => x.id === m)) ||
      !mw ||
      !/^\d+$/.test(w || "") ||
      !/^\d+$/.test(d || "") ||
      Number(w) >= mw.num_weeks ||
      Number(d) > 6
    ) {
      selected = null;
      error = "This session link is no longer valid. Choose a day in Meso.";
      return;
    }
    const identifier = `${mw.id}:${w}:${d}`;
    if (parsedDay !== identifier) {
      extra = {};
      parsedDay = identifier;
    }
    selected = { week: Number(w), day: Number(d) };
    const requestedSlot = routeUrl.searchParams.get("slot") || "";
    const [slotId, index] = requestedSlot.split(":");
    const validSlot =
      slotId &&
      plan(tables, mw.id, Number(w), Number(d)).some(
        (e) => e.slotId === slotId,
      ) &&
      /^\d+$/.test(index || "") &&
      Number(index) <
        Math.max(
          (target(tables, mw.id, Number(w), slotId)?.reps.length ?? 3) +
            (extra[slotId] || 0),
          ...entries(tables, mw.id, Number(w), Number(d))
            .filter((e) => e.slot_id === slotId)
            .map((e) => e.set_index + 1),
        );
    activeSet = validSlot ? requestedSlot : "";
    if (requestedSlot && !validSlot)
      error =
        "This set is no longer in the session. The first unfinished set is selected.";
  }
  function chooseDay(w: number, d: number, navigate = true) {
    activeSet = "";
    extra = {};
    goto(routeFor("/log", w, d), { reset: navigate });
  }
  function activateSet(slot: string, index: number) {
    activeSet = `${slot}:${index}`;
    goto(routeFor("/log", week, day, activeSet), {
      replaceState: true,
      reset: false,
    });
  }
  function resetToday() {
    selected = null;
    activeSet = "";
    extra = {};
    goto(routeFor("/log"), { replaceState: true, reset: false });
  }
  function revealSelectedWeek(picker: HTMLDivElement, weekIndex: number) {
    async function reveal(index: number) {
      await tick();
      const button = picker.children[index];
      if (!button || button.getAttribute("aria-pressed") !== "true") return;
      const viewport = picker.getBoundingClientRect();
      const bounds = button.getBoundingClientRect();
      const left = bounds.left - viewport.left - 8;
      const right = bounds.right - viewport.right + 8;
      picker.scrollBy({ left: Math.min(0, left) + Math.max(0, right) });
    }
    void reveal(weekIndex);
    return { update: reveal };
  }
  function beginSwipe(event: TouchEvent) {
    touchStart = null;
    const e = event.target as HTMLElement;
    if (e.closest(".week-picker,button,input,a,select,textarea")) return;
    touchStart = {
      x: event.changedTouches[0].clientX,
      y: event.changedTouches[0].clientY,
    };
  }
  function finishSwipe(event: TouchEvent) {
    if (!touchStart || !meso) return;
    const dx = event.changedTouches[0].clientX - touchStart.x,
      dy = event.changedTouches[0].clientY - touchStart.y;
    touchStart = null;
    if (Math.abs(dx) > 75 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      stepDay(dx < 0 ? 1 : -1, false);
    }
  }
  function stepDay(offset: number, reset = true) {
    const next = week * days.length + day + offset;
    if (meso && next >= 0 && next < meso.num_weeks * days.length)
      chooseDay(Math.floor(next / days.length), next % days.length, reset);
  }
  function nextActive() {
    for (const e of items) {
      const t = target(tables, meso!.id, week, e.slotId);
      for (let i = 0; i < (t?.reps.length ?? 3); i++)
        if (
          !currentEntries.some(
            (r: Row) =>
              r.slot_id === e.slotId && r.set_index === i && truth(r.done),
          )
        )
          return `${e.slotId}:${i}`;
    }
    return "";
  }
  function slotEntries(slot: string) {
    return currentEntries
      .filter((e: Row) => e.slot_id === slot && truth(e.done))
      .sort((a: Row, b: Row) => a.set_index - b.set_index);
  }
  function suggestion(id: string) {
    return previousSets.get(id);
  }
  function previousSetIndex(rows: Row[], excludingSession?: string) {
    const result = new Map<string, Row>();
    for (const row of rows) {
      if (
        !truth(row.done) ||
        row.set_index !== 0 ||
        row.session_id === excludingSession
      )
        continue;
      const previous = result.get(row.exercise_id);
      if (
        !previous ||
        dateValue(row.logged_at).getTime() >
          dateValue(previous.logged_at).getTime()
      ) {
        result.set(row.exercise_id, row);
      }
    }
    return result;
  }
  async function saveSet(
    e: Row,
    i: number,
    w: number | null,
    r: number,
    ri: number,
  ) {
    await run(async () => {
      const s = await command("getOrCreateSessionLog", {
        mesoId: meso!.id,
        weekIdx: week,
        dayIdx: day,
      });
      await command("upsertSetEntry", {
        sessionId: s.id,
        exerciseId: e.id,
        slotId: e.slotId,
        setIndex: i,
        weight: w,
        reps: r,
        rir: ri,
        done: true,
        loggedAt: new Date().toISOString(),
      });
      activeSet = "";
      goto(routeFor("/log", week, day), { replaceState: true, reset: false });
    });
  }
  function groupNameForPicker(e: Row) {
    return groups.includes(e.group) ? e.group : "other";
  }
  function picker(g: string, select: (e: Row) => void) {
    pickerGroup = groups.includes(g) ? g : "other";
    pickerSearch = "";
    customName = "";
    pickerSelect = select;
    push({ kind: "picker", title: "Choose exercise" });
  }
  async function addCustom() {
    await run(async () => {
      const e = await command("findOrCreateExerciseByName", {
        name: customName.trim(),
        group: pickerGroup,
      });
      pickerSelect(e);
    });
  }
  function targetEditor(e: Row, w: number, importExercise?: Row) {
    const t = importExercise
      ? importTarget(importExercise, w)
      : target(tables, meso!.id, w, e.slotId);
    push({
      kind: "target",
      title: `Week ${w + 1} target`,
      e,
      w,
      importExercise,
      reps: [...(t?.reps || [8, 8, 8])],
      rir: [...(t?.rir || [2, 2, 2])],
    });
  }
  function resizeSets(n: number) {
    if (!sheet) return;
    while (sheet.reps.length < n) {
      sheet.reps = [...sheet.reps, sheet.reps.at(-1) || 8];
      sheet.rir = [...sheet.rir, sheet.rir.at(-1) ?? 2];
    }
    sheet.reps = sheet.reps.slice(0, n);
    sheet.rir = sheet.rir.slice(0, n);
    sheet = sheet;
  }
  async function saveTarget(forward = false) {
    const s = sheet!;
    await run(async () => {
      if (s.importExercise) {
        for (let w = s.w; w < (forward ? review!.numWeeks : s.w + 1); w++) {
          const t = { weekIdx: w, reps: [...s.reps], rir: [...s.rir] };
          const i = s.importExercise.weekTargets.findIndex(
            (x: Row) => x.weekIdx === w,
          );
          if (i >= 0) s.importExercise.weekTargets[i] = t;
          else s.importExercise.weekTargets.push(t);
        }
        review = { ...review! };
      } else
        await command(forward ? "applyWeekTargetForward" : "upsertWeekTarget", {
          mesoId: meso!.id,
          weekIdx: s.w,
          fromWeekIdx: s.w,
          numWeeks: meso!.num_weeks,
          slotId: s.e.slotId,
          reps: s.reps,
          rir: s.rir,
        });
      close();
    }, "Targets saved");
  }
  function editProgram(d: number) {
    const es = program(tables, meso!.id, d).map((e: Row) => ({ ...e }));
    open({
      kind: "program",
      title: `Edit ${days[d]}`,
      day: d,
      label: label(tables, meso!.id, d) || "",
      items: es,
    });
  }
  async function saveProgram() {
    const s = sheet!;
    const overrides = (tables.day_overrides || []).filter(
      (o: Row) =>
        o.mesocycle_id === meso!.id && o.day_idx === s.day && o.week_idx > 0,
    );
    if (overrides.length && !s.confirmed) {
      push({
        kind: "confirm",
        title: "Overwrite week overrides?",
        message: `Saving this program will replace custom exercise lists in weeks ${overrides.map((o: Row) => o.week_idx + 1).join(", ")}.`,
        action: async () => {
          close();
          sheet!.confirmed = true;
          await saveProgram();
        },
      });
      return;
    }
    await run(async () => {
      const ids = [];
      for (const e of s.items) {
        if (!e.slotId) {
          const slot = await command("createExerciseSlot", {
            mesoId: meso!.id,
            exerciseId: e.id,
          });
          e.slotId = slot.id;
        }
        ids.push(e.slotId);
      }
      await command("setWeekForwardOverride", {
        mesoId: meso!.id,
        fromWeek: 0,
        numWeeks: meso!.num_weeks,
        dayIdx: s.day,
        slotIds: ids,
      });
      await command("setDayOverride", {
        mesoId: meso!.id,
        weekIdx: -1,
        dayIdx: s.day,
        slotIds: ids,
      });
      await command("upsertProgramDay", {
        mesoId: meso!.id,
        dayIdx: s.day,
        label: s.label.trim() || null,
      });
      close();
    }, "Program updated");
  }
  function move<T>(xs: T[], from: number, to: number) {
    if (to < 0 || to >= xs.length) return xs;
    const a = [...xs];
    a.splice(to, 0, a.splice(from, 1)[0]);
    return a;
  }
  async function swapExercise(
    e: Row,
    d: number,
    scope: string,
    newExercise: Row,
  ) {
    await run(async () => {
      const start = scope === "program" ? 0 : week;
      const slot = await command("createExerciseSlot", {
        mesoId: meso!.id,
        exerciseId: newExercise.id,
      });
      const t = target(tables, meso!.id, start, e.slotId);
      if (t)
        await command(
          scope === "session" ? "upsertWeekTarget" : "applyWeekTargetForward",
          {
            mesoId: meso!.id,
            weekIdx: start,
            fromWeekIdx: start,
            numWeeks: meso!.num_weeks,
            slotId: slot.id,
            reps: t.reps,
            rir: t.rir,
          },
        );
      const es =
        scope === "program"
          ? program(tables, meso!.id, d)
          : plan(tables, meso!.id, start, d);
      const ids = es.map((x: Row) =>
        x.slotId === e.slotId ? slot.id : x.slotId,
      );
      await command(
        scope === "session" ? "setDayOverride" : "setWeekForwardOverride",
        {
          mesoId: meso!.id,
          weekIdx: start,
          fromWeek: start,
          numWeeks: meso!.num_weeks,
          dayIdx: d,
          slotIds: ids,
        },
      );
      if (scope !== "session" && start === 0)
        await command("setDayOverride", {
          mesoId: meso!.id,
          weekIdx: -1,
          dayIdx: d,
          slotIds: ids,
        });
      sheet = null;
      stack = [];
    }, "Exercise swapped");
  }
  function showArc(e: Row) {
    const t = target(tables, meso!.id, 0, e.slotId);
    open({
      kind: "arc",
      title: "Progression arc",
      e,
      sets: (t?.reps || [8]).map((r: number, i: number) => ({
        startReps: r,
        endReps: r,
        startRir: t?.rir[i] ?? 3,
        endRir: t?.rir[i] ?? 3,
      })),
    });
  }
  function confirm(title: string, message: string, action: () => Promise<any>) {
    push({ kind: "confirm", title, message, action });
  }
  async function confirmAction() {
    const action = sheet!.action;
    await run(async () => {
      await action();
      if (sheet?.kind === "confirm") close();
    });
  }
  function nameDialog(action: string, m?: Row) {
    push({
      kind: "name",
      title:
        action === "create" ? "New mesocycle" : `${title(action)} mesocycle`,
      action,
      m,
      value: action === "duplicate" ? `${m!.name} copy` : m?.name || "",
    });
  }
  async function saveName() {
    const s = sheet!;
    await run(async () => {
      if (s.action === "create")
        await command("createMeso", { name: s.value.trim() });
      else
        await command(s.action === "rename" ? "renameMeso" : "duplicateMeso", {
          id: s.m.id,
          name: s.value.trim(),
          newName: s.value.trim(),
        });
      selected = null;
      sheet = null;
      stack = [];
      goto("/meso");
    }, "Mesocycle saved");
  }
  async function showGuides(e: Row) {
    push({
      kind: "guides",
      title: e.name,
      loading: true,
      videos: [],
      error: "",
    });
    const s = sheet;
    try {
      const result = await api(`guides?exercise=${encodeURIComponent(e.name)}`);
      if (sheet === s) sheet = { ...s, videos: result.videos, loading: false };
    } catch {
      if (sheet === s)
        sheet = {
          ...s,
          loading: false,
          error: "Could not load guides. You can still search YouTube.",
        };
    }
  }
  async function restoreWorkflows() {
    try {
      tabId = sessionStorage.getItem("sg-tab") || crypto.randomUUID();
      sessionStorage.setItem("sg-tab", tabId);
      workflowId = sessionStorage.getItem("sg-workflow") || "";
      const [draft, request, generation, active] = await Promise.all([
        readDraft<Row>(`review:${workflowId}`),
        readDraft<Row>(`request:${workflowId}`),
        readDraft<Row>(`generation:${tabId}`),
        readDraft<string>(`active:${workflowId}`),
      ]);
      await loadSavedWorkflows();
      if (active && !draft) {
        job = { id: active };
        jobError = "A saved AI job is ready to resume.";
      }
      if (draft) review = draft;
      if (request) {
        pendingJob = request;
        lastJob = { kind: request.kind, input: request.input };
        jobError =
          "A saved job request needs recovery. Retry sends the same request ID.";
      }
      if (generation) {
        description = generation.description || "";
        experience = generation.experience || "intermediate";
        goal = generation.goal || "mix";
        sport = generation.sport || "";
        numWeeks = generation.numWeeks || 5;
        trainingDays = generation.trainingDays || 4;
        basis = generation.basis || "";
        basisMode = generation.basisMode || "inspiration";
      }
      workflowReady = true;
    } catch (e) {
      error = "Could not open saved workflow drafts: " + String(e);
    }
  }
  $: if (workflowReady && review)
    writeDraft(`review:${workflowId}`, review).catch(
      (e) => (error = String(e)),
    );
  $: if (workflowReady)
    writeDraft(`generation:${tabId}`, {
      description,
      experience,
      goal,
      sport,
      numWeeks,
      trainingDays,
      basis,
      basisMode,
    }).catch((e) => (error = String(e)));
  async function startJob(kind: string, input: Row) {
    if (!aiAvailable) return;
    review = null;
    const body = {
      id: crypto.randomUUID(),
      epoch: $training.epoch,
      kind,
      input,
    };
    pendingJob = body;
    workflowId = body.id;
    sessionStorage.setItem("sg-workflow", workflowId);
    await writeDraft(`request:${body.id}`, body);
    lastJob = { kind, input };
    await submitJob(body);
  }
  async function submitJob(body: Row) {
    const version = ++taskVersion;
    workflowId = body.id;
    sessionStorage.setItem("sg-workflow", workflowId);
    jobBusy = true;
    jobError = "";
    jobStatus = "Starting…";
    review = null;
    sheet = null;
    stack = [];
    await goto("/import");
    try {
      const j = await api("jobs", "POST", body);
      await writeDraft(`active:${body.id}`, j.id);
      await writeDraft(`request:${body.id}`, undefined);
      pendingJob = null;
      await pollJob(j.id, version);
    } catch (e) {
      if (version === taskVersion) {
        jobError = String(e);
        jobBusy = false;
      }
    }
  }
  async function retryJob() {
    if (pendingJob) await submitJob(pendingJob);
    else if (job) await pollJob(job.id);
    else {
      const saved = await readDraft<Row>(`request:${workflowId}`);
      if (saved) {
        pendingJob = saved;
        await submitJob(saved);
      } else if (lastJob) await startJob(lastJob.kind, lastJob.input);
    }
  }
  async function pollJob(id: string, version = ++taskVersion) {
    workflowId = id;
    sessionStorage.setItem("sg-workflow", id);
    jobBusy = true;
    jobError = "";
    while (version === taskVersion) {
      try {
        job = await api(`jobs/${id}`);
        jobStatus = job!.progress || "Working…";
        if (job!.state === "complete") {
          review = normalizePlan(job!.result);
          jobBusy = false;
          return;
        }
        if (["failed", "cancelled", "unavailable"].includes(job!.state))
          throw Error(job!.error || `Job ${job!.state}`);
        await new Promise((resolve) => setTimeout(resolve, 2000));
      } catch (e) {
        if (version === taskVersion) {
          jobError = String(e);
          jobBusy = false;
        }
        return;
      }
    }
  }
  async function generate() {
    if (!description.trim()) return;
    const prior = basis ? mesos.find((m: Row) => m.id === basis) : null;
    await startJob("generate", {
      description: description.trim(),
      numWeeks: basisMode === "progress" && prior ? prior.num_weeks : numWeeks,
      experienceLevel: experience,
      goal,
      trainingDays: basisMode === "progress" && prior ? null : trainingDays,
      sportContext: sport,
      exerciseLibrary: (tables.exercises || []).map((e: Row) => ({
        name: e.name,
        group: e.group,
      })),
      priorMeso: prior ? exportPlan(tables, prior) : null,
      basisMode,
    });
  }
  async function importCsv(event: Event) {
    const input = event.target as HTMLInputElement;
    const f = input.files?.[0];
    input.value = "";
    if (!f || !aiAvailable) return;
    const bytes = await f.arrayBuffer();
    let csv;
    try {
      csv = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    } catch {
      csv = new TextDecoder("windows-1252").decode(bytes);
    }
    await startJob("csv", { csv });
  }
  async function fixPlan(data: Row, advisories: Row[]) {
    await startJob("fix", {
      data,
      advisories,
      experienceLevel: experience,
      goal,
      sportContext: sport,
      description,
      exerciseLibrary: (tables.exercises || []).map((e: Row) => ({
        name: e.name,
        group: e.group,
      })),
    });
  }
  async function importBlock() {
    if (!review) return;
    await run(async () => {
      review!.days.forEach((d: Row, i: number) => (d.dayIdx = i));
      await command("importMesoFromPlan", { data: review });
      await writeDraft(`review:${workflowId}`, undefined);
      await writeDraft(`active:${workflowId}`, undefined);
      review = null;
      selected = null;
      goto("/meso");
    }, "Training block imported");
  }
  async function loadSavedWorkflows() {
    const [requests, reviews] = await Promise.all([
      listDrafts("request:"),
      listDrafts("review:"),
    ]);
    savedWorkflows = [
      ...requests.map((d) => ({ ...d, kind: "request" })),
      ...reviews.map((d) => ({ ...d, kind: "review" })),
    ];
  }
  async function recoverWorkflow(d: Row) {
    review = null;
    workflowId = d.key.slice(d.key.indexOf(":") + 1);
    sessionStorage.setItem("sg-workflow", workflowId);
    sheet = null;
    jobError = "";
    await goto("/import");
    if (d.kind === "request") {
      pendingJob = d.value;
      review = null;
      jobError =
        "A saved job request needs recovery. Retry sends the same request ID.";
    } else {
      pendingJob = null;
      review = normalizePlan(d.value);
    }
  }
  async function showJobs() {
    await loadSavedWorkflows();
    open({ kind: "jobs", title: "AI jobs", loading: true, jobs: [] });
    try {
      const result = await api("jobs");
      const js = Array.isArray(result) ? result : result.jobs || [];
      sheet = {
        kind: "jobs",
        title: "AI jobs",
        jobs: js,
        loading: false,
        cursor: result.nextCursor,
      };
    } catch {
      const ids: string[] = [];
      const js = await Promise.all(
        ids.map(async (id: string) => {
          try {
            return await api(`jobs/${id}`);
          } catch {
            return { id, kind: "AI job", state: "unavailable" };
          }
        }),
      );
      sheet = { kind: "jobs", title: "AI jobs", jobs: js, loading: false };
    }
  }
  async function loadMoreJobs() {
    const s = sheet!;
    if (!s.cursor) return;
    await run(async () => {
      const r = await api(
        `jobs?beforeCreated=${encodeURIComponent(s.cursor.createdAt)}&beforeId=${encodeURIComponent(s.cursor.id)}`,
      );
      sheet = { ...s, jobs: [...s.jobs, ...r.jobs], cursor: r.nextCursor };
    });
  }
  async function resumeJob(j: Row) {
    sheet = null;
    await goto("/import");
    review = null;
    job = j;
    await pollJob(j.id);
  }
  async function backup() {
    await run(async () => {
      await training.sync();
      if ($training.pending)
        throw Error("Sync or resolve pending changes before backing up.");
      const r = await fetch("/api/v1/backups");
      if (!r.ok) throw Error("Backup failed");
      const a = document.createElement("a");
      a.href = URL.createObjectURL(await r.blob());
      a.download = "strength-guru.sqlite";
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    }, "Backup downloaded");
  }
  async function inspectRestore(event: Event) {
    const f = (event.target as HTMLInputElement).files?.[0];
    if (!f) return;
    await run(async () => {
      const r = await fetch("/api/v1/backups/inspect", {
        method: "POST",
        headers: { "content-type": "application/vnd.sqlite3" },
        body: f,
      });
      const result = await r.json();
      if (!r.ok)
        throw Error(
          result.message || result.error || "Could not inspect backup",
        );
      push({ kind: "restore", title: "Restore backup", preview: result });
    });
    (event.target as HTMLInputElement).value = "";
  }
  async function restore() {
    await run(async () => {
      await training.restore(sheet!.preview.token);
      selected = null;
      sheet = null;
    }, "Backup restored");
  }
  async function applyUpdate() {
    if ($training.pending) return;
    confirm(
      "Reload app update?",
      "Your synced changes are safe. This reloads the app.",
      async () => {
        worker = await navigator.serviceWorker.getRegistration();
        if (worker?.waiting) {
          navigator.serviceWorker.addEventListener(
            "controllerchange",
            () => location.reload(),
            { once: true },
          );
          worker.waiting.postMessage("activate");
        } else location.reload();
      },
    );
  }
  function volume() {
    open({
      kind: "volume",
      title: "Volume Check",
      experience: "intermediate",
      goal: "hypertrophy",
      sport: "",
      advisories: null,
    });
  }
  function reviewChanged() {
    review = { ...review! };
  }
</script>

{#snippet aiLockNotice(id: string)}
  {#if !aiAvailable}
    <p {id} class="hint" role="status">
      {aiAvailable === null
        ? "Checking AI availability…"
        : "AI features are locked because server inference is unavailable."}
    </p>
  {/if}
{/snippet}

<svelte:head><title>StrengthGuru</title></svelte:head>
<input
  class="hidden"
  type="file"
  accept=".csv,text/csv"
  disabled={!aiAvailable}
  bind:this={importFile}
  on:change={importCsv}
/>
<input
  class="hidden"
  type="file"
  accept=".sqlite,.db,.sqlite3,application/vnd.sqlite3"
  bind:this={restoreFile}
  on:change={inspectRestore}
/>
<div class="app-shell">
  <button
    class="sync-banner"
    on:click={() => open({ kind: "sync", title: "Sync and pending changes" })}
    ><Icon
      name={$training.connected ? "cloud_done_outlined" : "cloud_off"}
      size={16}
    /><span
      >{$training.conflicts.length
        ? `${$training.conflicts.length} changes need review`
        : $training.pending
          ? `${$training.pending} changes pending sync`
          : $training.connected
            ? "Synced"
            : "Offline · saved on this device"}</span
    ><span class="push"><Icon name="chevron_right" size={16} /></span></button
  >
  <main id="main">
    {#if $training.ready && view === "/log"}
      <header class="session-header row" style={groupStyle(group)}>
        <h1 class="grow">
          {effective
            ? split
              ? `${split}${split.endsWith("Session") ? "" : " Session"}`
              : `${title(group)} Session`
            : "Log"}
        </h1>
        {#if today && (today.week !== week || today.day !== day)}
          <button class="soft today-shortcut" on:click={resetToday}
            >Today</button
          >
        {/if}
        <button
          class="soft rep-calculator"
          aria-label="Rep Calculator"
          on:click={() => open({ kind: "calculator", title: "Rep Calculator" })}
          ><Icon name="calculate_outlined" size={18} /> Rep calc</button
        >
      </header>
    {/if}
    {#if !$training.ready}
      <div class="empty">
        <span class="spinner"></span>
        <p>Opening your training data…</p>
        {#if $training.error}<p class="warning">{$training.error}</p>
          <button class="solid" on:click={() => training.initialize()}
            >Retry</button
          >{/if}
      </div>
    {:else if view === "/generate"}
      <div class="page narrow">
        <header class="page-heading">
          <a class="icon" href="/meso" aria-label="Back to mesocycle"
            ><Icon name="arrow_back" size={18} /></a
          >
          <h1>Generate Program</h1>
        </header>
        <section class="card form">
          <h2>Describe your program</h2>
          <p class="muted">
            Include your split, goals, experience, and exercise preferences.
          </p>
          <label
            >Program description<textarea
              bind:value={description}
              rows="5"
              placeholder="A four-day upper/lower split, with a focus on strength…"
            ></textarea></label
          >
          <label
            >Base on prior mesocycle (optional)<select bind:value={basis}
              ><option value="">None</option>{#each mesos as m}<option
                  value={m.id}>{m.name}</option
                >{/each}</select
            ></label
          >
          {#if basis}<div class="segmented">
              <button
                class:selected={basisMode === "inspiration"}
                on:click={() => (basisMode = "inspiration")}>Inspiration</button
              ><button
                class:selected={basisMode === "progress"}
                on:click={() => (basisMode = "progress")}
                >Progress prior block</button
              >
            </div>
            <p class="hint">
              {basisMode === "progress"
                ? "Keeps your prior split and block length, progressing the program."
                : "Use the prior program as a starting point."}
            </p>{/if}
          <div class="two">
            <label
              >Experience<select bind:value={experience}
                >{#each ["beginner", "intermediate", "advanced"] as x}<option
                    value={x}>{title(x)}</option
                  >{/each}</select
              ></label
            ><label
              >Goal<select bind:value={goal}
                ><option value="strength">Strength</option><option
                  value="hypertrophy">Hypertrophy</option
                ><option value="mix">Mixed</option></select
              ></label
            >
          </div>
          <fieldset disabled={!!basis && basisMode === "progress"}>
            <div class="two">
              <Stepper
                bind:value={trainingDays}
                min={1}
                max={7}
                label="TRAINING DAYS / WEEK"
              /><Stepper bind:value={numWeeks} min={1} max={16} label="WEEKS" />
            </div>
          </fieldset>
          <label
            >Sport / Context (optional)<input
              bind:value={sport}
              placeholder="climbing, running, BJJ, general fitness…"
            /></label
          >{@render aiLockNotice("generate-ai-status")}<button
            class="solid accent"
            disabled={!aiAvailable || !description.trim() || jobBusy}
            aria-describedby={aiAvailable ? undefined : "generate-ai-status"}
            on:click={generate}>Generate Program →</button
          >
        </section>
      </div>
    {:else if view === "/import"}
      <div class="page">
        <header class="page-heading">
          <a href="/meso" class="icon" aria-label="Back to mesocycle"
            ><Icon name="arrow_back" size={18} /></a
          >
          <h1>{review ? "Review training block" : "Import training block"}</h1>
        </header>
        {#if job?.dataset_epoch && job.dataset_epoch !== $training.epoch}
          <p class="warning" role="status">
            This result was created before the server dataset was restored.
            Review its exercises and targets before importing it into the
            current dataset.
          </p>
        {/if}
        {#if jobBusy}<section class="empty card">
            <span class="spinner"></span>
            <h2>Building your program…</h2>
            <p aria-live="polite">{jobStatus}</p>
            <details open>
              <summary>Thinking</summary>
              <pre>{jobStatus}</pre>
            </details>
            <p class="hint">
              You can return to your training. This job is saved.
            </p>
            <button class="soft" on:click={showJobs}>AI jobs</button>
          </section>
        {:else if jobError}<section class="card form">
            <h2>Could not finish this job</h2>
            <p class="warning" role="alert">{jobError}</p>
            <div class="row">
              <button class="solid" on:click={retryJob}>Retry</button><button
                class="soft"
                on:click={showJobs}>Saved jobs</button
              >
            </div>
          </section>
        {:else if review}<section class="review-header">
            <label class="eyebrow"
              >PLAN NAME<input
                class="title-input"
                bind:value={review.name}
              /></label
            >
            <div class="row">
              <span class="chip">{review.numWeeks} WEEKS</span><span
                class="chip">{review.days.length} DAYS</span
              >{#if review.skippedDayLabels?.length}<span class="chip warning"
                  >{review.skippedDayLabels.length} DAYS SKIPPED</span
                >{/if}
            </div>
          </section>
          {#if review.advisories?.length}<section class="card advisories">
              <div class="row">
                <h3>Plan review</h3>
                <button
                  class="soft push"
                  disabled={!aiAvailable}
                  aria-describedby={aiAvailable
                    ? undefined
                    : "review-ai-status"}
                  on:click={() => fixPlan(review!, review!.advisories)}
                  >Fix with AI</button
                >
              </div>
              {@render aiLockNotice("review-ai-status")}
              {#each review.advisories as a, i}<div class="row advisory">
                  <span class:warning={a.severity === "warn"}>{a.message}</span
                  ><button
                    class="icon push"
                    aria-label="Dismiss advisory"
                    on:click={() => {
                      review!.advisories.splice(i, 1);
                      reviewChanged();
                    }}><Icon name="close" size={18} /></button
                  >
                </div>{/each}
            </section>{/if}
          <div class="timeline-scroll import-grid">
            <div class="timeline-grid" style={`--weeks:${review.numWeeks}`}>
              <div class="timeline-header">
                <span></span>{#each Array(review.numWeeks) as _, w}<span
                    >W{w + 1}</span
                  >{/each}
              </div>
              {#each review.days as d, di}<section class="timeline-day">
                  <div class="row day-heading">
                    <button
                      class="icon"
                      disabled={di === 0}
                      aria-label={`Move ${d.label} earlier`}
                      on:click={() => {
                        review!.days = move(review!.days, di, di - 1);
                        reviewChanged();
                      }}><Icon name="arrow_upward" size={18} /></button
                    ><button
                      class="icon"
                      disabled={di === review!.days.length - 1}
                      aria-label={`Move ${d.label} later`}
                      on:click={() => {
                        review!.days = move(review!.days, di, di + 1);
                        reviewChanged();
                      }}><Icon name="arrow_downward" size={18} /></button
                    ><input
                      aria-label={`Day ${di + 1} label`}
                      bind:value={d.label}
                    /><button
                      class="icon"
                      aria-label="Collapse day"
                      on:click={() => {
                        d.collapsed = !d.collapsed;
                        reviewChanged();
                      }}
                      ><Icon
                        name={d.collapsed ? "expand_more" : "expand_less"}
                        size={18}
                      /></button
                    ><button
                      class="icon"
                      aria-label={`Delete ${d.label}`}
                      on:click={() => {
                        review!.days.splice(di, 1);
                        reviewChanged();
                      }}><Icon name="close" size={18} /></button
                    >
                  </div>
                  {#if !d.collapsed}{#each d.exercises as e, ei}<div
                        class="timeline-row"
                        style={groupStyle(e.muscleGroup)}
                      >
                        <button
                          class="exercise-name"
                          on:click={() =>
                            picker(e.muscleGroup, (p) => {
                              Object.assign(e, {
                                name: p.name,
                                muscleGroup: p.group,
                              });
                              close();
                              reviewChanged();
                            })}
                          ><span
                            class="dot"
                            class:new-exercise={!(tables.exercises || []).some(
                              (x: Row) =>
                                x.name.toLowerCase() === e.name.toLowerCase(),
                            )}
                          ></span>{e.name}</button
                        >{#each Array(review.numWeeks) as _, w}{@const t =
                            importTarget(e, w)}<button
                            class="timeline-cell"
                            on:click={() => targetEditor(e, w, e)}
                            ><b>{formatReps(t.reps)}</b><small
                              >{formatRir(t.rir)}</small
                            ></button
                          >{/each}<button
                          class="icon remove-exercise"
                          aria-label={`Delete ${e.name}`}
                          on:click={() => {
                            d.exercises.splice(ei, 1);
                            reviewChanged();
                          }}><Icon name="close" size={18} /></button
                        >
                      </div>{/each}{/if}
                </section>{/each}
            </div>
          </div>
          {#if review.days.length < 7}<button
              class="ghost full"
              on:click={() => {
                review!.days.push({
                  dayIdx: review!.days.length,
                  label: "Rest Day",
                  exercises: [],
                });
                reviewChanged();
              }}>+ Add Rest Day</button
            >{/if}
          <p class="hint">
            ● Existing exercise · <span class="warning">● Will be created</span>
          </p>
          <button
            class="solid accent full sticky-import"
            disabled={busy || !review.name.trim()}
            on:click={importBlock}>{busy ? "Saving…" : "Import Block"}</button
          >
        {:else}<section class="empty card">
            <h2>Import your next block.</h2>
            {#if aiAvailable}<p class="muted">
                Choose a CSV or describe a program to generate.
              </p>{/if}
            {@render aiLockNotice("import-ai-status")}
            <button
              class="solid"
              disabled={!aiAvailable}
              aria-describedby={aiAvailable ? undefined : "import-ai-status"}
              on:click={() => importFile.click()}>Import CSV</button
            >{#if aiAvailable}<a href="/generate" class="soft"
                ><Icon name="auto_awesome_outlined" size={18} /> Generate Program</a
              >{:else}<button
                class="soft"
                disabled
                aria-describedby="import-ai-status">Generate Program</button
              >{/if}<button class="ghost" on:click={showJobs}
              >AI jobs and saved results</button
            >{#if pendingJob}<button class="soft" on:click={retryJob}
                >Recover saved job request</button
              >{/if}
          </section>{/if}
      </div>
    {:else if !meso}
      <div class="empty">
        {#if view === "/log"}<h2>No active mesocycle.</h2>{:else}<h1>
            No active mesocycle.
          </h1>{/if}
        <p class="muted">Create one in the Meso tab.</p>
        <button
          class="solid accent"
          on:click={() => open({ kind: "switcher", title: "Mesocycles" })}
          >+ New Mesocycle</button
        ><button
          class="ghost"
          on:click={() => open({ kind: "about", title: "About StrengthGuru" })}
          >Backup and restore</button
        >
      </div>
    {:else if view === "/meso"}
      <div class="page">
        <div class="row">
          <p class="eyebrow">CURRENT MESOCYCLE</p>
          <button
            class="icon push"
            aria-label="Check program volume"
            on:click={volume}
            ><Icon name="fact_check_outlined" size={18} /></button
          ><button
            class="icon"
            aria-label="About, backup and restore"
            on:click={() =>
              open({ kind: "about", title: "About StrengthGuru" })}
            ><Icon name="info_outlined" size={18} /></button
          >
        </div>
        <button
          class="meso-name full row"
          on:click={() => open({ kind: "switcher", title: "Mesocycles" })}
          ><h1>{meso!.name}</h1>
          <span class="push muted"><Icon name="expand_more" size={18} /></span
          ></button
        >
        <p class="muted">
          {meso!.num_weeks} weeks · started {dateValue(
            meso!.start_date,
          ).toLocaleDateString("en-CA")}
        </p>
        <div class="segmented viz">
          <button
            class:selected={viz === "calendar"}
            on:click={() => (viz = "calendar")}>Calendar</button
          ><button
            class:selected={viz === "timeline"}
            on:click={() => (viz = "timeline")}>Timeline</button
          >
        </div>
        {#if viz === "calendar"}<div class="calendar">
            <div class="calendar-labels">
              {#each days as d}<span>{d.slice(0, 3).toUpperCase()}</span
                >{/each}<span></span>
            </div>
            {#each Array(meso!.num_weeks) as _, w}<div
                class="calendar-week"
                class:current={today?.week === w}
              >
                <span class="sr-only">Week {w + 1}</span
                >{#each days as _, d}{@const es = plan(
                    tables,
                    meso!.id,
                    w,
                    d,
                  )}{@const g = primary(es)}<button
                    class="calendar-day"
                    class:rest={g === "rest"}
                    class:past={today &&
                      (w < today.week || (w === today.week && d < today.day))}
                    class:today={today?.week === w && today?.day === d}
                    class:deload={deloads.includes(w)}
                    style={groupStyle(g)}
                    aria-label={`Week ${w + 1}, ${days[d]}, ${title(g)}${session(tables, meso!.id, w, d) ? ", session started" : ""}`}
                    on:click={() => chooseDay(w, d)}
                    >{#if session(tables, meso!.id, w, d)}<Icon
                        name="check"
                        size={16}
                      />{:else if deloads.includes(w) && g !== "rest"}D{/if}</button
                  >{/each}<button
                  class="deload-toggle"
                  class:warning={deloads.includes(w)}
                  aria-label={`Toggle deload week ${w + 1}`}
                  on:click={() =>
                    run(() =>
                      command("toggleDeloadWeek", {
                        mesoId: meso!.id,
                        weekIdx: w,
                      }),
                    )}>{deloads.includes(w) ? "D" : "−"}</button
                ><button
                  class="delete-week icon"
                  disabled={meso!.num_weeks <= 1}
                  aria-label={`Delete week ${w + 1}`}
                  on:click={() =>
                    confirm(
                      "Delete week?",
                      `Remove week ${w + 1} and its logs? Later weeks shift back.`,
                      () =>
                        command("deleteWeek", { mesoId: meso!.id, weekIdx: w }),
                    )}><Icon name="delete_outlined" size={16} /></button
                >
              </div>{/each}
            <div class="calendar-legend">
              <span>□ Today</span><span
                ><Icon name="check" size={16} /> Session started</span
              ><span>D Deload</span>
            </div>
          </div>
        {:else}<div class="timeline-scroll">
            <div class="timeline-grid" style={`--weeks:${meso!.num_weeks}`}>
              <div class="timeline-header">
                <span></span>{#each Array(meso!.num_weeks) as _, w}<button
                    class:warning={deloads.includes(w)}
                    aria-label={`Toggle deload week ${w + 1}`}
                    on:click={() =>
                      run(() =>
                        command("toggleDeloadWeek", {
                          mesoId: meso!.id,
                          weekIdx: w,
                        }),
                      )}>{deloads.includes(w) ? "DELOAD" : `W${w + 1}`}</button
                  >{/each}
              </div>
              {#each days as d, di}{@const es = program(
                  tables,
                  meso!.id,
                  di,
                )}{@const g = primary(es)}
                <section class="timeline-day" style={groupStyle(g)}>
                  <div class="day-heading row">
                    <span class="group-bar"></span>
                    <h3>{(label(tables, meso!.id, di) || d).toUpperCase()}</h3>
                    <button
                      class="icon"
                      aria-label={`Swap ${d} with another day`}
                      on:click={() =>
                        open({
                          kind: "day-picker",
                          title: `Swap ${d} with…`,
                          day: di,
                          action: "swap",
                        })}><Icon name="swap_horiz" size={18} /></button
                    ><button
                      class="icon"
                      aria-label={`Edit ${d} program`}
                      on:click={() => editProgram(di)}
                      ><Icon name="edit" size={18} /></button
                    ><button
                      class="icon"
                      aria-label={`${d} actions`}
                      on:click={() =>
                        open({ kind: "day-actions", title: d, day: di })}
                      ><Icon name="more_vert" size={18} /></button
                    >
                  </div>
                  {#each es as e}<div
                      class="timeline-row"
                      style={groupStyle(e.group)}
                    >
                      <button
                        class="exercise-name"
                        on:click={() =>
                          open({
                            kind: "exercise-actions",
                            title: e.name,
                            e,
                            day: di,
                          })}>{e.name}</button
                      >{#each Array(meso!.num_weeks) as _, w}{@const t = target(
                          tables,
                          meso!.id,
                          w,
                          e.slotId,
                        )}<button
                          class="timeline-cell"
                          on:click={() => targetEditor(e, w)}
                          ><b>{formatReps(t?.reps || [])}</b><small
                            >{formatRir(t?.rir || [])}</small
                          ></button
                        >{/each}
                    </div>{/each}{#if !es.length}<p class="hint">
                      Rest day · use the pencil to add exercises
                    </p>{/if}
                </section>{/each}
            </div>
          </div>{/if}
        <button
          class="ghost full"
          disabled={busy}
          on:click={() =>
            run(() =>
              command("setMesoNumWeeks", {
                id: meso!.id,
                numWeeks: meso!.num_weeks + 1,
              }),
            )}>+ Add week</button
        >
        {#if today}<button
            class="solid full"
            on:click={() => chooseDay(today!.week, today!.day)}
            >Today's Session →</button
          >{/if}
        <div class="settings-row">
          <button
            on:click={() =>
              confirm(
                "Re-seed?",
                "Wipes training data and recreates the starter mesocycle.",
                async () => {
                  await command("forceReseed", {});
                  selected = null;
                },
              )}><Icon name="refresh" size={18} /> Re-seed</button
          ><button
            on:click={() => open({ kind: "week", title: "Set Current Week" })}
            ><Icon name="calendar_today" size={18} /> Set week</button
          ><button
            class="warning"
            on:click={() =>
              confirm(
                "Wipe all data?",
                "Permanently deletes all training data. This cannot be undone.",
                async () => {
                  await command("wipeAllData", {});
                  selected = null;
                },
              )}><Icon name="delete_outlined" size={18} /> Wipe data</button
          >
        </div>
      </div>
    {:else if !effective}
      <div class="empty">
        <h2>
          {meso && dateValue(meso!.start_date) > new Date()
            ? "Your mesocycle starts soon."
            : "Mesocycle complete!"}
        </h2>
        <p class="muted">Choose a session or start your next block in Meso.</p>
        <a class="solid" href="/meso">Open Meso →</a>
      </div>
    {:else if view === "/log"}
      <div
        class="log-page"
        role="region"
        aria-label="Training session"
        style={groupStyle(group)}
        on:touchstart={beginSwipe}
        on:touchend={finishSwipe}
        on:touchcancel={() => (touchStart = null)}
      >
        <div class="week-picker" use:revealSelectedWeek={week}>
          {#each Array(meso!.num_weeks) as _, w}<button
              class:selected={w === week}
              aria-pressed={w === week}
              on:click={() => chooseDay(w, day, false)}>WEEK {w + 1}</button
            >{/each}
        </div>
        <div class="day-picker">
          {#each days as d, di}{@const g = primary(
              plan(tables, meso!.id, week, di),
            )}<button
              class:selected={day === di}
              aria-pressed={day === di}
              style={groupStyle(g)}
              aria-label={d}
              on:click={() => chooseDay(week, di, false)}>{d[0]}</button
            >{/each}
        </div>
        {#if !items.length}<div class="empty">
            <h2>Recovery day.</h2>
            <p class="muted">Rest up.</p>
          </div>{:else}{#key `${meso.id}:${week}:${day}`}<div
              class="exercise-list"
            >
              {#each items as e (e.slotId)}{@const t = target(
                  tables,
                  meso!.id,
                  week,
                  e.slotId,
                )}{@const es = slotEntries(e.slotId)}{@const count = Math.max(
                  (t?.reps.length ?? 3) + (extra[e.slotId] || 0),
                  es.length
                    ? Math.max(...es.map((x: Row) => x.set_index)) + 1
                    : 0,
                )}
                <section class="card exercise-card" style={groupStyle(e.group)}>
                  <header class="row">
                    <span class="dot"></span>
                    <h2>{e.name}</h2>
                    <button
                      class="icon push"
                      aria-label={`Exercise guide for ${e.name}`}
                      on:click={() => showGuides(e)}
                      ><Icon name="play_circle_outline" size={18} /></button
                    >{#if es.length >= count}<span class="chip success-text"
                        >DONE</span
                      >{/if}<button
                      class="icon"
                      aria-label={`Swap ${e.name}`}
                      on:click={() =>
                        open({
                          kind: "swap",
                          title: "Swap Exercise",
                          e,
                          day,
                          scope: "session",
                        })}><Icon name="swap_horiz" size={18} /></button
                    >
                  </header>
                  {#if t}<p class="eyebrow target-description">
                      TARGET · {formatReps(t.reps)} · {formatRir(t.rir)}
                    </p>{/if}{#each Array(count) as _, i}{@const saved =
                      es.find((x: Row) => x.set_index === i)}<SetRow
                      index={i}
                      reps={t?.reps[i] ?? t?.reps.at(-1) ?? 10}
                      rir={t?.rir[i] ?? t?.rir.at(-1) ?? 2}
                      entry={saved}
                      recent={es.filter((x: Row) => x.set_index < i).at(-1)}
                      suggestion={suggestion(e.id)}
                      active={(activeSet || nextActive()) ===
                        `${e.slotId}:${i}`}
                      activate={() => activateSet(e.slotId, i)}
                      save={(w, r, ri) => saveSet(e, i, w, r, ri)}
                    />{/each}<button
                    class="soft add-set"
                    on:click={() => {
                      extra = {
                        ...extra,
                        [e.slotId]: (extra[e.slotId] || 0) + 1,
                      };
                      activeSet = `${e.slotId}:${count}`;
                    }}>+ Add set</button
                  >
                </section>{/each}
            </div>{/key}{/if}
        <footer class="session-pager two">
          <button
            class="soft"
            disabled={week === 0 && day === 0}
            on:click={() => stepDay(-1)}
            ><Icon name="arrow_back" size={18} /> Previous day</button
          >
          <button
            class="soft"
            disabled={week === meso!.num_weeks - 1 && day === days.length - 1}
            on:click={() => stepDay(1)}
            >Next day <Icon name="arrow_forward" size={18} /></button
          >
        </footer>
      </div>
    {/if}
  </main>
  <nav class="bottom-tabs" aria-label="Main navigation">
    <a
      href={routeFor("/log")}
      class:selected={view === "/log"}
      aria-current={view === "/log" ? "page" : undefined}
      ><Icon
        name={view === "/log" ? "fitness_center" : "fitness_center_outlined"}
      /><small>LOG</small></a
    ><a
      href={routeFor("/meso")}
      class:selected={view === "/meso"}
      aria-current={view === "/meso" ? "page" : undefined}
      ><Icon name={view === "/meso" ? "loop" : "loop_outlined"} /><small
        >MESO</small
      ></a
    >
  </nav>
</div>
{#if toast}<div class="toast" role="status">{toast}</div>{/if}
{#if error && !sheet}<div class="error-toast" role="alert">
    <span>{error}</span><button
      class="icon"
      aria-label="Dismiss error"
      on:click={() => (error = "")}><Icon name="close" size={18} /></button
    >
  </div>{/if}
{#if sheet}
  <Sheet
    title={sheet.title}
    {close}
    wide={sheet.kind === "arc" || sheet.kind === "program"}
  >
    {#if dialogError}<p class="alert warning" role="alert">
        {dialogError}
      </p>{/if}
    {#if sheet.kind === "confirm"}<p>{sheet.message}</p>
      <div class="two actions">
        <button class="soft" on:click={close}>Cancel</button><button
          class="solid accent"
          disabled={busy}
          on:click={confirmAction}>{busy ? "Working…" : "Confirm"}</button
        >
      </div>
    {:else if sheet.kind === "name"}<form on:submit|preventDefault={saveName}>
        <label
          >Mesocycle name<input
            bind:value={sheet.value}
            required
            maxlength="200"
          /></label
        >
        <div class="two actions">
          <button type="button" class="soft" on:click={close}>Cancel</button
          ><button class="solid" disabled={busy || !sheet.value.trim()}
            >Save</button
          >
        </div>
      </form>
    {:else if sheet.kind === "switcher"}<div class="switcher-list">
        {#each mesos as m}<div class="meso-option row">
            <button
              class="grow text-left"
              disabled={truth(m.is_active) || busy}
              on:click={() =>
                run(async () => {
                  await command("activateMeso", { id: m.id });
                  selected = null;
                  close();
                  goto("/meso");
                })}
              ><strong>{m.name}</strong><small
                >{m.num_weeks} weeks{truth(m.is_active)
                  ? " · ACTIVE"
                  : ""}</small
              ></button
            ><button
              class="icon"
              aria-label={`Manage ${m.name}`}
              on:click={() => push({ kind: "meso-actions", title: m.name, m })}
              ><Icon name="more_vert" size={18} /></button
            >
          </div>{/each}
      </div>
      <button class="solid full" on:click={() => nameDialog("create")}
        >+ New Mesocycle</button
      >{@render aiLockNotice("switcher-ai-status")}<button
        class="soft full"
        disabled={!aiAvailable}
        aria-describedby={aiAvailable ? undefined : "switcher-ai-status"}
        on:click={() => importFile.click()}>Import CSV</button
      >{#if aiAvailable}<a
          class="soft full"
          href="/generate"
          on:click={() => (sheet = null)}>Generate Program</a
        >{:else}<button
          class="soft full"
          disabled
          aria-describedby="switcher-ai-status">Generate Program</button
        >{/if}
    {:else if sheet.kind === "meso-actions"}<button
        class="soft full"
        on:click={() => nameDialog("rename", sheet!.m)}>Rename</button
      ><button
        class="soft full"
        on:click={() => nameDialog("duplicate", sheet!.m)}>Duplicate</button
      ><button
        class="ghost full warning"
        on:click={() => {
          const m = sheet!.m;
          confirm(
            "Delete mesocycle?",
            `Delete “${m.name}” and its training logs?`,
            async () => {
              await command("deleteMeso", { id: m.id });
              selected = null;
              sheet = null;
              stack = [];
            },
          );
        }}>Delete mesocycle</button
      >
    {:else if sheet.kind === "program"}<label
        >Split name<input
          bind:value={sheet.label}
          placeholder="Chest & Shoulders"
        /></label
      >
      <div class="program-list">
        {#each sheet.items as e, i}<div
            class="row program-item"
            draggable="true"
            on:dragstart={() => (dragIndex = i)}
            on:dragover|preventDefault
            on:drop|preventDefault={() => {
              sheet!.items = move(sheet!.items, dragIndex, i);
              sheet = sheet;
            }}
            role="group"
            aria-label={e.name}
          >
            <div class="reorder-buttons">
              <button
                class="icon"
                aria-label={`Move ${e.name} up`}
                disabled={i === 0}
                on:click={() => {
                  sheet!.items = move(sheet!.items, i, i - 1);
                  sheet = sheet;
                }}><Icon name="arrow_upward" size={18} /></button
              ><button
                class="icon"
                aria-label={`Move ${e.name} down`}
                disabled={i === sheet!.items.length - 1}
                on:click={() => {
                  sheet!.items = move(sheet!.items, i, i + 1);
                  sheet = sheet;
                }}><Icon name="arrow_downward" size={18} /></button
              >
            </div>
            <div class="grow">
              <strong>{e.name}</strong><small class="eyebrow">{e.group}</small>
            </div>
            <button
              class="icon"
              aria-label={`Remove ${e.name}`}
              on:click={() => {
                sheet!.items = sheet!.items.filter(
                  (_: Row, j: number) => j !== i,
                );
                sheet = sheet;
              }}><Icon name="close" size={18} /></button
            >
          </div>{/each}
      </div>
      <button
        class="ghost full"
        on:click={() =>
          picker(primary(sheet!.items), (e) => {
            close();
            sheet!.items = [...sheet!.items, { ...e, slotId: null }];
            sheet = sheet;
          })}>+ Add exercise</button
      ><button class="solid full" disabled={busy} on:click={saveProgram}
        >Save Changes</button
      ><button
        class="ghost full warning"
        on:click={() => {
          const d = sheet!.day;
          confirm(
            "Reset program day?",
            "Remove this day’s base program and split label?",
            async () => {
              await command("clearProgramDay", { mesoId: meso!.id, dayIdx: d });
              sheet = null;
            },
          );
        }}>Reset to default</button
      >
    {:else if sheet.kind === "picker"}<div class="form">
        <label
          >Find an exercise<input
            bind:value={pickerSearch}
            placeholder="Search exercises…"
          /></label
        >
        <div class="group-picker">
          {#each groups.filter((g) => g !== "rest") as g}<button
              class:selected={pickerGroup === g}
              style={groupStyle(g)}
              on:click={() => (pickerGroup = g)}>{title(g)}</button
            >{/each}
        </div>
        <p class="eyebrow">{title(pickerGroup)} exercises</p>
        <div class="picker-list">
          {#each (tables.exercises || []).filter((e: Row) => groupNameForPicker(e) === pickerGroup && e.name
                .toLowerCase()
                .includes(pickerSearch.toLowerCase())) as e}<div class="row">
              <button
                class="picker-exercise grow"
                on:click={() => pickerSelect(e)}>{e.name}</button
              ><button
                class="icon"
                aria-label={`Guide for ${e.name}`}
                on:click={() => showGuides(e)}
                ><Icon name="play_circle_outline" size={18} /></button
              >
            </div>{/each}
          <p class="eyebrow">OTHER GROUPS</p>
          {#each (tables.exercises || []).filter((e: Row) => groupNameForPicker(e) !== pickerGroup && e.name
                .toLowerCase()
                .includes(pickerSearch.toLowerCase())) as e}<div class="row">
              <button
                class="picker-exercise grow"
                on:click={() => pickerSelect(e)}
                >{e.name}<small>{title(e.group)}</small></button
              ><button
                class="icon"
                aria-label={`Guide for ${e.name}`}
                on:click={() => showGuides(e)}
                ><Icon name="play_circle_outline" size={18} /></button
              >
            </div>{/each}
        </div>
        <label
          >Add custom exercise<input
            bind:value={customName}
            placeholder="Exercise name"
          /></label
        ><button
          class="soft full"
          disabled={busy ||
            !customName.trim() ||
            (tables.exercises || []).some(
              (e: Row) =>
                e.name.trim().toLowerCase() === customName.trim().toLowerCase(),
            )}
          on:click={addCustom}>Add to {title(pickerGroup)}</button
        >
      </div>
    {:else if sheet.kind === "swap"}<p class="muted">
        Replace {sheet.e.name}. Existing logs are preserved.
      </p>
      <div class="segmented">
        <button
          class:selected={sheet.scope === "session"}
          on:click={() => {
            sheet!.scope = "session";
            sheet = sheet;
          }}>This session</button
        ><button
          class:selected={sheet.scope === "forward"}
          on:click={() => {
            sheet!.scope = "forward";
            sheet = sheet;
          }}>This week onward</button
        >
      </div>
      <button
        class="solid full"
        on:click={() => {
          const s = sheet!;
          picker(s.e.group, (e) => swapExercise(s.e, s.day, s.scope, e));
        }}>Choose replacement exercise</button
      >
    {:else if sheet.kind === "exercise-actions"}<button
        class="soft full"
        on:click={() => showArc(sheet!.e)}
        ><Icon name="trending_up" size={18} /> Set progression arc</button
      ><button
        class="soft full"
        on:click={() => {
          const s = sheet!;
          picker(s.e.group, (e) => swapExercise(s.e, s.day, "program", e));
        }}
        ><Icon name="swap_horiz" size={18} /> Swap exercise across all weeks</button
      ><button class="ghost full" on:click={() => showGuides(sheet!.e)}
        ><Icon name="play_circle_outline" size={18} /> Exercise guide</button
      >
    {:else if sheet.kind === "target"}<h3>{sheet.e.name}</h3>
      <div class="row set-count">
        <button
          class="soft"
          disabled={sheet.reps.length <= 1}
          on:click={() => resizeSets(sheet!.reps.length - 1)}>− Set</button
        ><span class="eyebrow">{sheet.reps.length} SETS</span><button
          class="soft"
          disabled={sheet.reps.length >= 10}
          on:click={() => resizeSets(sheet!.reps.length + 1)}>+ Set</button
        >
      </div>
      {#each sheet.reps as r, i}<div class="target-set">
          <p class="eyebrow">SET {i + 1}</p>
          <div class="two">
            <Stepper
              bind:value={sheet.reps[i]}
              min={1}
              max={99}
              label="REPS"
            /><Stepper bind:value={sheet.rir[i]} min={0} max={5} label="RIR" />
          </div>
        </div>{/each}<button
        class="ghost full"
        on:click={() => {
          sheet!.reps = sheet!.reps.map(() => sheet!.reps[0]);
          sheet!.rir = sheet!.rir.map(() => sheet!.rir[0]);
          sheet = sheet;
        }}>Make all sets same as Set 1</button
      ><button
        class="soft full"
        disabled={busy}
        on:click={() => saveTarget(true)}
        >Apply from week {sheet.w + 1} onward →</button
      ><button
        class="solid full"
        disabled={busy}
        on:click={() => saveTarget(false)}>Done · this week</button
      >
    {:else if sheet.kind === "arc"}<h3>{sheet.e.name}</h3>
      {#each sheet.sets as s, i}<section class="arc-set card">
          <div class="row">
            <p class="eyebrow">SET {i + 1}</p>
            <button
              class="icon push"
              disabled={sheet.sets.length <= 1}
              aria-label={`Delete progression set ${i + 1}`}
              on:click={() => {
                sheet!.sets = sheet!.sets.filter(
                  (_: Row, j: number) => j !== i,
                );
                sheet = sheet;
              }}><Icon name="close" size={18} /></button
            >
          </div>
          <p class="eyebrow">START · W1</p>
          <div class="two">
            <Stepper
              bind:value={s.startReps}
              min={1}
              max={99}
              label="REPS"
            /><Stepper bind:value={s.startRir} min={0} max={5} label="RIR" />
          </div>
          <p class="eyebrow">FINISH · LAST ACTIVE WEEK</p>
          <div class="two">
            <Stepper
              bind:value={s.endReps}
              min={1}
              max={99}
              label="REPS"
            /><Stepper bind:value={s.endRir} min={0} max={5} label="RIR" />
          </div>
        </section>{/each}<button
        class="ghost full"
        on:click={() => {
          sheet!.sets = [
            ...sheet!.sets,
            { startReps: 8, endReps: 8, startRir: 3, endRir: 3 },
          ];
          sheet = sheet;
        }}>+ Add set</button
      >
      <p class="eyebrow">PREVIEW</p>
      <div class="arc-preview">
        {#each progression(sheet.sets, meso!.num_weeks, deloads) as t}<div>
            <small
              >W{t.weekIdx + 1}{deloads.includes(t.weekIdx)
                ? " · DL"
                : ""}</small
            >{#each t.reps as r, i}<span>{r} · RIR {t.rir[i]}</span>{/each}
          </div>{/each}
      </div>
      <button
        class="solid full"
        disabled={busy}
        on:click={() => {
          const s = sheet!;
          run(async () => {
            await command("applyExerciseProgression", {
              mesoId: meso!.id,
              numWeeks: meso!.num_weeks,
              slotId: s.e.slotId,
              sets: s.sets,
              deloadWeeks: deloads,
            });
            close();
          }, "Progression applied");
        }}>Apply Arc</button
      >
    {:else if sheet.kind === "day-actions"}<button
        class="soft full"
        on:click={() => {
          sheet = {
            kind: "day-picker",
            title: "Duplicate to…",
            day: sheet!.day,
            action: "duplicate",
          };
        }}>Duplicate To…</button
      ><button
        class="ghost full warning"
        on:click={() => {
          const d = sheet!.day;
          confirm(
            "Clear day?",
            "Exercises and targets for this day will be removed across all weeks.",
            async () => {
              await command("clearDay", { mesoId: meso!.id, dayIdx: d });
              sheet = null;
            },
          );
        }}>Clear Day</button
      >
    {:else if sheet.kind === "day-picker"}{#each days as d, i}{#if i !== sheet.day && (sheet.action !== "duplicate" || program(tables, meso!.id, i).length === 0)}<button
            class="soft full text-left"
            on:click={() => {
              const s = sheet!;
              run(
                async () => {
                  await command(
                    s.action === "duplicate" ? "duplicateDay" : "swapDays",
                    {
                      mesoId: meso!.id,
                      fromIdx: s.day,
                      toIdx: i,
                      dayA: s.day,
                      dayB: i,
                    },
                  );
                  close();
                },
                s.action === "duplicate" ? "Day duplicated" : "Days swapped",
              );
            }}
            >{d}<small
              >{label(tables, meso!.id, i) ||
                title(primary(program(tables, meso!.id, i)))}</small
            ></button
          >{/if}{/each}{#if sheet.action === "duplicate" && !days.some((_, i) => i !== sheet!.day && !program(tables, meso!.id, i).length)}<p
          class="muted"
        >
          No empty days available. Clear a day first.
        </p>{/if}
    {:else if sheet.kind === "week"}{#each Array(meso!.num_weeks) as _, w}<button
          class="soft full"
          on:click={() =>
            run(async () => {
              await command("setMesoCurrentWeek", {
                id: meso!.id,
                targetWeekIdx: w,
              });
              selected = null;
              close();
              goto("/meso", { replaceState: true });
            })}>Week {w + 1}</button
        >{/each}
    {:else if sheet.kind === "calculator"}<div class="segmented">
        {#each [["estimate", "Est. 1RM"], ["weight", "Weight"], ["reps", "Reps"]] as [m, l]}<button
            class:selected={calcMode === m}
            on:click={() => (calcMode = m)}>{l}</button
          >{/each}
      </div>
      <div class="form">
        {#if calcMode === "estimate"}<Stepper
            bind:value={calcWeight}
            step={2.5}
            label="WEIGHT (KG)"
          />{:else}<Stepper
            bind:value={calcOne}
            step={2.5}
            label="1RM (KG)"
          />{/if}{#if calcMode === "reps"}<Stepper
            bind:value={calcLift}
            step={2.5}
            label="WEIGHT (KG)"
          />{:else}<div class="two">
            <Stepper
              bind:value={calcReps}
              min={1}
              max={50}
              label="TARGET REPS"
            /><Stepper bind:value={calcRir} min={0} max={10} label="RIR" />
          </div>{/if}
        <div class="segmented">
          <button
            class:selected={formula === "epley"}
            on:click={() => (formula = "epley")}>Epley</button
          ><button
            class:selected={formula === "brzycki"}
            on:click={() => (formula = "brzycki")}>Brzycki</button
          >
        </div>
        <div class="calculator-result" aria-live="polite">
          <p class="eyebrow">
            {calcMode === "estimate"
              ? "ESTIMATED 1RM"
              : calcMode === "weight"
                ? "SUGGESTED WEIGHT"
                : "ESTIMATED REPS"}
          </p>
          <strong>{calculation}</strong>
        </div>
      </div>
    {:else if sheet.kind === "guides"}{#if sheet.loading}<span class="spinner"
        ></span>{/if}{#if sheet.error}<p class="muted">
          {sheet.error}
        </p>{/if}{#each sheet.videos as v}<a
          class="soft full text-left"
          href={`/guide/${v.id}`}
          target="_blank"
          rel="noreferrer"
          ><Icon name="play_circle_outline" size={18} /> {v.title} ↗</a
        >{/each}<a
        class="ghost full"
        href={`https://www.youtube.com/results?search_query=${encodeURIComponent(sheet.title + " exercise form tutorial")}`}
        target="_blank"
        rel="noreferrer">Search YouTube ↗</a
      >
    {:else if sheet.kind === "volume"}<p class="muted">
        Verify weekly sets against recommended MEV/MRV ranges.
      </p>
      <div class="two">
        <label
          >Experience<select bind:value={sheet.experience}
            >{#each ["beginner", "intermediate", "advanced"] as x}<option
                value={x}>{title(x)}</option
              >{/each}</select
          ></label
        ><label
          >Goal<select bind:value={sheet.goal}
            ><option value="strength">Strength</option><option
              value="hypertrophy">Hypertrophy</option
            ><option value="mix">Mixed</option></select
          ></label
        >
      </div>
      <label
        >Sport / Context (optional)<input
          bind:value={sheet.sport}
          placeholder="climbing, running, BJJ…"
        /></label
      ><button
        class="solid full"
        on:click={() => {
          sheet!.advisories = validateVolume(
            exportPlan(tables, meso!),
            sheet!.experience,
            sheet!.goal,
          );
          sheet = sheet;
        }}>Run Validation</button
      >{#if sheet.advisories}{#if !sheet.advisories.length}<p
            class="success-text"
          >
            <Icon name="check_circle_outlined" size={20} /> No volume concerns found.
          </p>{:else}<div class="advisories">
            {#each sheet.advisories as a}<p
                class:warning={a.severity === "warn"}
              >
                <Icon
                  name={a.severity === "warn"
                    ? "warning_amber_rounded"
                    : "info_outlined"}
                  size={16}
                />
                {a.message}
              </p>{/each}
          </div>
          <button
            class="soft full"
            disabled={!aiAvailable}
            aria-describedby={aiAvailable ? undefined : "volume-ai-status"}
            on:click={() => {
              experience = sheet!.experience;
              goal = sheet!.goal;
              sport = sheet!.sport;
              fixPlan(exportPlan(tables, meso!), sheet!.advisories);
            }}>Fix with AI</button
          >{@render aiLockNotice("volume-ai-status")}{/if}{/if}
    {:else if sheet.kind === "about"}<div class="two stats">
        <section class="stat">
          <div>
            <p class="eyebrow">VERSION</p>
            <strong>{metadata.version}</strong>
          </div>
        </section>
        <section class="stat">
          <div>
            <p class="eyebrow">REVISION</p>
            <strong
              >{(import.meta.env.VITE_GIT_SHA || "development").slice(
                0,
                7,
              )}</strong
            >
          </div>
        </section>
      </div>
      <a
        class="soft full"
        href="https://github.com/maxnaro/strength-guru"
        target="_blank"
        rel="noreferrer"><Icon name="code" size={18} /> GitHub Repository</a
      >
      <div class="two">
        <button class="soft" disabled={busy} on:click={backup}
          ><Icon name="backup_outlined" size={18} /> Backup</button
        ><button
          class="soft"
          disabled={busy}
          on:click={() => restoreFile.click()}
          ><Icon name="settings_backup_restore" size={18} /> Restore</button
        >
      </div>
      <p class="hint">Backups include all mesocycles and training logs.</p>
    {:else if sheet.kind === "restore"}<p>
        Restoring replaces the current server training data. Review this backup
        before continuing.
      </p>
      <table class="restore-preview">
        <caption>Backup contents</caption>
        <tbody>
          <tr
            ><th scope="row">Programs</th><td
              >{sheet.preview.counts?.mesocycles ?? 0}</td
            ></tr
          >
          <tr
            ><th scope="row">Exercises</th><td
              >{sheet.preview.counts?.exercises ?? 0}</td
            ></tr
          >
          <tr
            ><th scope="row">Sessions</th><td
              >{sheet.preview.counts?.session_logs ?? 0}</td
            ></tr
          >
          <tr
            ><th scope="row">Logged sets</th><td
              >{sheet.preview.counts?.set_entries ?? 0}</td
            ></tr
          >
        </tbody>
      </table>
      <p class="hint">
        A recovery snapshot is saved on the server before replacement.
      </p>
      <div class="two">
        <button class="soft" on:click={close}>Cancel</button><button
          class="solid accent"
          disabled={busy}
          on:click={restore}>Restore this backup</button
        >
      </div>
    {:else if sheet.kind === "sync"}<p class="muted">
        {$training.error ||
          ($training.connected
            ? "Your changes are saved and synchronized."
            : "Your logs are saved on this device until you reconnect.")}
      </p>
      <button
        class="solid full"
        disabled={busy}
        on:click={() => run(() => training.sync(), "Sync finished")}
        >Retry sync</button
      ><button
        class="soft full"
        on:click={() =>
          run(async () =>
            download(
              await training.exportPending(),
              "strength-guru-pending.json",
            ),
          )}>Export pending changes</button
      ><button
        class="soft full"
        disabled={$training.pending > 0}
        on:click={applyUpdate}
        ><Icon name="system_update_alt" size={18} /> Apply app update{updateReady
          ? " · ready"
          : ""}</button
      >{#if $training.pending}<p class="hint">
          Sync or export and resolve pending changes before updating.
        </p>{/if}<button class="ghost full" on:click={showJobs}
        >AI jobs and saved results</button
      ><button
        class="ghost full"
        on:click={() =>
          run(async () => {
            const raw = JSON.parse(await training.exportPending());
            sheet = {
              kind: "pending",
              title: "Pending changes",
              rows: Array.isArray(raw)
                ? raw
                : raw.operations || raw.outbox || raw.pending || [],
            };
          })}>Review all {$training.pending} pending changes</button
      >{#each conflicts as c}<section class="conflict">
          <strong>{c.body?.type || "Change needs review"}</strong>
          <p class="muted">
            {c.error || "This change conflicts with the server version."}
          </p>
          {#if c.body?.type === "upsertSetEntry" || c.body?.type === "deleteSetEntry"}
            <div class="two">
              <section>
                <h3>Your retained change</h3>
                {#if c.body.type === "deleteSetEntry"}
                  <p>Remove this set</p>
                {:else}
                  <p>
                    {c.localValue?.weight ?? "—"} kg · {c.localValue?.reps ??
                      "—"} reps · RIR {c.localValue?.rir ?? "—"}
                  </p>
                {/if}
              </section>
              <section>
                <h3>Server version</h3>
                {#if c.serverValue}
                  <p>
                    {c.serverValue.weight ?? "—"} kg · {c.serverValue.reps ??
                      "—"} reps · RIR {c.serverValue.rir ?? "—"}
                  </p>
                {:else}
                  <p>This set no longer exists.</p>
                {/if}
              </section>
            </div>
          {/if}
          {#if ["program_changed", "dataset_changed", "deleted_reference"].includes(c.code)}
            <p class="hint">
              Export this change before discarding it, then review the current
              program and log it in the intended session.
            </p>
          {/if}
          {#if c.code === "result_unconfirmed"}
            <p>
              This program change was saved on the server. Retry the original
              action to recover its result, or acknowledge it here.
            </p>
          {/if}
          <div class="two">
            <button
              class="soft"
              disabled={[
                "program_changed",
                "dataset_changed",
                "deleted_reference",
                "result_unconfirmed",
              ].includes(c.code)}
              on:click={() => run(() => training.keepLocal(c.id))}
              >Keep my edit</button
            ><button
              class="ghost warning"
              on:click={() =>
                confirm(
                  c.code === "result_unconfirmed"
                    ? "Acknowledge saved result?"
                    : "Discard local change?",
                  c.code === "result_unconfirmed"
                    ? "This clears the local confirmation record. The saved server change remains."
                    : "The server version will be used. Export pending changes first to retain a copy.",
                  () => training.discard(c.id),
                )}
              >{c.code === "result_unconfirmed"
                ? "Acknowledge saved result"
                : "Use server version"}</button
            >
          </div>
        </section>{/each}
    {:else if sheet.kind === "pending"}{#if !sheet.rows.length}<p>
          No pending changes.
        </p>{/if}{#each sheet.rows as c}<section class="conflict">
          <strong>{c.body?.type || c.type || "Queued change"}</strong>
          <p class="hint">{c.id}</p>
          <button
            class="ghost warning"
            on:click={() =>
              confirm(
                "Discard local change?",
                "Export pending changes first if you want to retain a copy. This local operation will be discarded.",
                async () => {
                  await training.discard(c.id);
                  close();
                  sheet!.rows = sheet!.rows.filter((r: Row) => r.id !== c.id);
                  sheet = sheet;
                },
              )}>Discard local change</button
          >
        </section>{/each}
    {:else if sheet.kind === "jobs"}
      {#if savedWorkflows.length}<h3>Saved on this device</h3>
        {#each savedWorkflows as d}<button
            class="soft full text-left"
            on:click={() => recoverWorkflow(d)}
            >{d.kind === "review"
              ? d.value.name || "Editable review"
              : "Recover " + d.value.kind + " request"}<small
              >{d.key.slice(d.key.indexOf(":") + 1)}</small
            ></button
          >{/each}
        <h3>Server jobs</h3>{/if}
      <button class="soft full" on:click={showJobs}
        ><Icon name="refresh" size={18} /> Refresh</button
      >{#if sheet.loading}<span class="spinner"
        ></span>{:else if !sheet.jobs.length}<p class="muted">
          Your AI jobs will appear here.
        </p>{/if}{#each sheet.jobs as j}<div class="row job-row">
          <button class="grow text-left" on:click={() => resumeJob(j)}
            ><strong>{title(j.kind || "AI job")} · {j.state}</strong><small
              >{j.progress || ""}</small
            ></button
          >{#if j.dataset_epoch && j.dataset_epoch !== $training.epoch}<small
              >From an earlier dataset</small
            >{/if}{#if ["queued", "running"].includes(j.state)}<button
              class="icon warning"
              aria-label="Cancel AI job"
              on:click={() =>
                run(async () => {
                  await api(`jobs/${j.id}`, "DELETE");
                  await showJobs();
                })}><Icon name="cancel_outlined" size={18} /></button
            >{/if}
        </div>{/each}{#if sheet.cursor}<button
          class="soft full"
          disabled={busy}
          on:click={loadMoreJobs}>Load earlier jobs</button
        >{/if}
    {/if}
  </Sheet>
{/if}
