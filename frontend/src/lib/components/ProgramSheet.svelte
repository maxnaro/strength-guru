<script lang="ts">
  import { tick } from "svelte";
  import { days, groupStyle, label, list, plan, program, type Row, type Tables } from "../domain/training";
  import Icon from "./Icon.svelte";

  export let tables: Tables;
  export let meso: Row;
  export let today: { week: number; day: number } | null;
  export let deloads: number[];
  export let busy: boolean;
  export let connected: boolean;
  export let programRevision: number;
  export let epoch = "";
  export let saveCell: (payload: Row, revision: number, epoch: string) => Promise<unknown>;
  export let onDayEdit: (day: number) => void;
  export let onDayActions: (day: number) => void;
  export let onDaySwap: (day: number) => void;
  export let onExerciseActions: (exercise: Row, day: number) => void;
  export let onTarget: (exercise: Row, week: number) => void;
  export let onDeload: (week: number) => void;

  type Metric = "reps" | "rir";
  type Values = Record<Metric, number[]>;
  type Cell = {
    id: string;
    row: number;
    col: number;
    exercise: Row;
    week: number;
    set: number;
    metric: Metric;
    values: Values;
    name: string;
  };
  type Edit = {
    cell: Cell;
    draft: string;
    revision: number;
    epoch: string;
    mesoId: string;
  };

  const metrics: Metric[] = ["reps", "rir"];
  let active = "";
  let edit: Edit | null = null;
  let error = "";
  let saving = false;
  let editor: HTMLInputElement;
  let grid: HTMLDivElement;

  $: weeks = Array.from({ length: meso.num_weeks }, (_, week) => week);
  $: schedule = buildSchedule(tables, meso.id, weeks);
  $: cells = schedule.flatMap((day) => day.exercises.flatMap((entry) =>
    entry.sets.flatMap((set) => set.flatMap((week) => week.cells.filter((cell): cell is Cell => cell !== null))),
  ));
  $: tabCell = cells.some((cell) => cell.id === active) ? active : cells[0]?.id;
  $: missingEditedCell = edit && !cells.some((cell) => cell.id === edit?.cell.id);

  function buildSchedule(data: Tables, mesoId: string, weekList: number[]) {
    const targetsByWeek = weekList.map(() => new Map<string, Values>());
    for (const target of data.week_targets || []) {
      if (target.mesocycle_id === mesoId) {
        targetsByWeek[target.week_idx]?.set(target.slot_id, {
          reps: list(target.reps),
          rir: list(target.rir),
        });
      }
    }
    let row = 0;
    return days.map((day, dayIndex) => {
      const scheduled = weekList.map((week) => plan(data, mesoId, week, dayIndex));
      const slotsByWeek = scheduled.map((items) => new Set(items.map((e) => e.slotId)));
      const scheduledIds = new Set(slotsByWeek.flatMap((ids) => [...ids]));
      const exercises = new Map<string, Row>();
      for (const exercise of [...program(data, mesoId, dayIndex), ...scheduled.flat()]) {
        if (scheduledIds.has(exercise.slotId)) exercises.set(exercise.slotId, exercise);
      }

      return {
        day,
        heading: label(data, mesoId, dayIndex),
        exercises: [...exercises.values()].map((exercise) => {
          const targets = slotsByWeek.map((slots, week) =>
            slots.has(exercise.slotId)
              ? targetsByWeek[week].get(exercise.slotId) ?? { reps: [8, 8, 8], rir: [2, 2, 2] }
              : null,
          );
          const setCount = Math.max(1, ...targets.map((values) => values?.reps.length ?? 0));
          const sets = Array.from({ length: setCount }, (_, set) => {
            const rowIndex = row++;
            return targets.map((values, week) => ({
              scheduled: values !== null,
              cells: metrics.map((metric, metricIndex): Cell | null =>
                values && values[metric][set] !== undefined
                  ? {
                      id: `${dayIndex}:${exercise.slotId}:${set}:${week}:${metric}`,
                      row: rowIndex,
                      col: week * metrics.length + metricIndex,
                      exercise, week, set, metric, values,
                      name: `${day}, ${exercise.name}, set ${set + 1}, week ${week + 1}, ${metric === "reps" ? "reps" : "RIR"}`,
                    }
                  : null,
              ),
            }));
          });
          return { exercise, sets };
        }),
      };
    });
  }

  function focusCell(cell: Cell) {
    active = cell.id;
    const button = grid.querySelector<HTMLButtonElement>(`[data-cell="${CSS.escape(cell.id)}"]`);
    button?.focus({ preventScroll: true });
    button?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }

  async function startEdit(cell: Cell, replacement?: string) {
    if (busy || !connected || saving || edit) return;
    edit = {
      cell,
      draft: replacement ?? String(cell.values[cell.metric][cell.set]),
      revision: programRevision,
      epoch,
      mesoId: meso.id,
    };
    error = "";
    await tick();
    editor?.focus();
    if (replacement === undefined) editor?.select();
  }

  function adjacentCell(cell: Cell, key: string, backwards = false) {
    if (key === "Tab") return cells[cells.findIndex((other) => other.id === cell.id) + (backwards ? -1 : 1)];
    if (key === "ArrowLeft" || key === "ArrowRight") {
      return key === "ArrowLeft"
        ? cells.findLast((other) => other.row === cell.row && other.col < cell.col)
        : cells.find((other) => other.row === cell.row && other.col > cell.col);
    }
    return key === "ArrowUp"
      ? cells.findLast((other) => other.col === cell.col && other.row < cell.row)
      : cells.find((other) => other.col === cell.col && other.row > cell.row);
  }

  function cellKey(event: KeyboardEvent, cell: Cell) {
    if (event.key === "Enter" || event.key === "F2") {
      event.preventDefault();
      void startEdit(cell);
    } else if (/^[0-9]$/.test(event.key) && !event.altKey && !event.ctrlKey && !event.metaKey) {
      event.preventDefault();
      void startEdit(cell, event.key);
    } else if (event.key.startsWith("Arrow") || event.key === "Tab") {
      const next = adjacentCell(cell, event.key, event.shiftKey);
      if (next || event.key !== "Tab") event.preventDefault();
      if (next) focusCell(next);
    }
  }

  function validationMessage(pending: Edit) {
    const [min, max] = pending.cell.metric === "reps" ? [1, 99] : [0, 5];
    const value = Number(pending.draft);
    return /^\d+$/.test(pending.draft.trim()) && value >= min && value <= max
      ? ""
      : `Enter a whole number from ${min} to ${max}.`;
  }

  async function commit(next?: Cell, restoreFocus = false) {
    if (!edit || saving) return;
    const pending = edit;
    const { cell } = pending;
    const value = Number(pending.draft);
    error = validationMessage(pending);
    if (error) return;
    const changed = value !== cell.values[cell.metric][cell.set];
    if (changed) {
      if (!connected || busy) {
        error = connected ? "Another change is saving. Try again." : "Reconnect to save this target.";
        return;
      }
      const values = { reps: [...cell.values.reps], rir: [...cell.values.rir] };
      values[cell.metric][cell.set] = value;
      saving = true;
      if (next) focusCell(next);
      try {
        await saveCell({
          mesoId: pending.mesoId,
          weekIdx: cell.week,
          slotId: cell.exercise.slotId,
          ...values,
        }, pending.revision, pending.epoch);
      } catch (cause) {
        error = cause instanceof Error ? cause.message : "Unable to save the target. Try again.";
        return;
      } finally {
        saving = false;
      }
    }
    const refocus = (restoreFocus || next) && document.activeElement === editor;
    edit = null;
    await tick();
    if (refocus) focusCell(next ?? cell);
  }

  async function editorKey(event: KeyboardEvent, cell: Cell) {
    if (event.key === "Escape") {
      event.preventDefault();
      if (saving) return;
      edit = null;
      error = "";
      await tick();
      focusCell(cell);
    } else if (event.key === "Enter" || event.key === "Tab") {
      const next = event.key === "Tab"
        ? adjacentCell(cell, event.key, event.shiftKey)
        : adjacentCell(cell, "ArrowDown");
      if (next || event.key === "Enter" || (edit && validationMessage(edit))) event.preventDefault();
      void commit(next, event.key === "Enter");
    }
  }
</script>

<div class="sheet-status" aria-live="polite">
  {#if missingEditedCell && edit}
    <span class="error">This cell is unavailable. Your draft was {edit.draft}.</span>
    <button class="dismiss-draft" disabled={saving} on:click={() => { edit = null; error = ""; }}>
      Discard draft
    </button>
  {:else if error}<span class="error">{error}</span>
  {:else if saving}Saving target…
  {:else if !connected}Reconnect to edit targets.
  {:else}Use arrow keys to move. Press Enter or double-click to edit.{/if}
</div>
<div class="program-sheet" bind:this={grid} style:--week-count={weeks.length}>
  <table aria-label="Mesocycle program">
    <colgroup><col class="exercise-column" /><col class="set-column" /></colgroup>
    {#each weeks as week (week)}<colgroup><col /><col /></colgroup>{/each}
    <thead>
      <tr>
        <th class="sticky-exercise" rowspan="2" scope="col">Exercise</th>
        <th class="sticky-set" rowspan="2" scope="col">Set</th>
        {#each weeks as week (week)}
          <th class:today-week={today?.week === week} colspan="2" scope="colgroup">
            <button class="week-heading" class:deload={deloads.includes(week)} disabled={busy || !connected}
              aria-label={`Toggle deload week ${week + 1}`} aria-pressed={deloads.includes(week)}
              on:click={() => onDeload(week)}>
              Week {week + 1}{#if deloads.includes(week)}<span>Deload</span>{/if}
            </button>
          </th>
        {/each}
      </tr>
      <tr>
        {#each weeks as week (week)}
          <th class="metric-heading" class:today-week={today?.week === week} scope="col">Reps</th>
          <th class="metric-heading week-end" class:today-week={today?.week === week} scope="col">RIR</th>
        {/each}
      </tr>
    </thead>
    {#each schedule as day, dayIndex (day.day)}
      <tbody>
        <tr class="day">
          <th class="day-group" colspan="2" scope="rowgroup">
            <div class="day-heading">
              <span class="day-title">{day.day}{#if day.heading}<small>{day.heading}</small>{/if}</span>
              <button class="action" aria-label={`Swap ${day.day} with another day`} on:click={() => onDaySwap(dayIndex)}><Icon name="swap_horiz" size={17} /></button>
              <button class="action" aria-label={`Edit ${day.day} program`} on:click={() => onDayEdit(dayIndex)}><Icon name="edit" size={17} /></button>
              <button class="action" aria-label={`${day.day} actions`} on:click={() => onDayActions(dayIndex)}><Icon name="more_vert" size={17} /></button>
            </div>
          </th>
          <td class="day-fill" colspan={weeks.length * 2}>{#if !day.exercises.length}Rest day{/if}</td>
        </tr>
        {#each day.exercises as { exercise, sets } (exercise.slotId)}
          {#each sets as set, setIndex (setIndex)}
            <tr class:first-set={setIndex === 0}>
              {#if setIndex === 0}
                <th class="sticky-exercise exercise" rowspan={sets.length} style={groupStyle(exercise.group)}>
                  <button class="exercise-action" aria-label={`${exercise.name} actions on ${day.day}`}
                    on:click={() => onExerciseActions(exercise, dayIndex)}>
                    <span>{exercise.name}</span><Icon name="more_vert" size={16} />
                  </button>
                </th>
              {/if}
              <th class="sticky-set set" scope="row">{setIndex + 1}</th>
              {#each set as { cells: weekCells, scheduled }, week (week)}
                {#each weekCells as cell, metricIndex (metricIndex)}
                  <td class:week-end={metricIndex === 1} class:current-day={today?.week === week && today?.day === dayIndex}
                    class:unavailable={!cell} class:with-action={setIndex === 0 && metricIndex === 1 && scheduled}>
                    {#if cell}
                      {#if edit?.cell.id === cell.id && edit?.mesoId === meso.id}
                        <input bind:this={editor} bind:value={edit.draft} type="text" inputmode="numeric"
                          aria-label={cell.name} aria-invalid={Boolean(error && validationMessage(edit))} readonly={saving}
                          on:keydown={(event) => editorKey(event, cell)} on:blur={() => commit()} />
                      {:else}
                        <button class="cell" data-cell={cell.id} tabindex={cell.id === tabCell ? 0 : -1}
                          aria-label={`${cell.name}, ${cell.values[cell.metric][cell.set]}`}
                          aria-disabled={!connected || busy || saving}
                          on:focus={() => (active = cell.id)}
                          on:keydown={(event) => cellKey(event, cell)}
                          on:dblclick={() => startEdit(cell)}>{cell.values[cell.metric][cell.set]}</button>
                      {/if}
                    {:else}
                      <span class="dash" aria-label={scheduled ? "No set" : "Not scheduled"}>—</span>
                    {/if}
                    {#if setIndex === 0 && metricIndex === 1 && scheduled}
                      <button class="action target-action" aria-label={`Edit ${exercise.name} targets for ${day.day}, week ${week + 1}`}
                        on:click={() => onTarget(exercise, week)}><Icon name="more_vert" size={15} /></button>
                    {/if}
                  </td>
                {/each}
              {/each}
            </tr>
          {/each}
        {/each}
      </tbody>
    {/each}
  </table>
</div>

<style>
  .sheet-status {
    color: var(--dim);
    font-size: 0.8rem;
    min-height: 1.6rem;
  }
  .error {
    color: var(--accent-text);
    font-weight: 700;
  }
  .dismiss-draft {
    color: var(--dim);
    text-decoration: underline;
  }
  .program-sheet {
    --exercise-width: 13rem;
    --set-width: 2.75rem;
    overflow: auto;
    max-height: min(70vh, 54rem);
    scroll-padding-block-start: 4.45rem;
    scroll-padding-inline-start: calc(var(--exercise-width) + var(--set-width));
    border: 1px solid var(--border-strong);
    border-radius: 0.75rem;
    background: var(--surface);
  }
  table {
    width: 100%;
    min-width: calc(var(--exercise-width) + var(--set-width) + var(--week-count) * 6.5rem);
    border-collapse: separate;
    border-spacing: 0;
    table-layout: fixed;
    font-size: 0.85rem;
  }
  .exercise-column { width: var(--exercise-width); }
  .set-column { width: var(--set-width); }
  th, td {
    padding: 0;
    border-bottom: 1px solid var(--border);
    text-align: center;
  }
  .week-end, .sticky-set { border-right: 1px solid var(--border-strong); }
  thead {
    position: sticky;
    top: 0;
    z-index: 3;
    background: var(--surface2);
  }
  thead th {
    background: var(--surface2);
  }
  thead tr:first-child th { border-right: 1px solid var(--border-strong); }
  .sticky-exercise, .sticky-set, .day-group {
    position: sticky;
    z-index: 1;
  }
  .sticky-exercise, .day-group { left: 0; }
  .sticky-set { left: var(--exercise-width); }
  .week-heading {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.35rem;
    width: 100%;
    min-height: 2.5rem;
    font-weight: 750;
  }
  .week-heading span {
    color: var(--warn-text);
    font-size: 0.72rem;
  }
  .deload { background: color-mix(in srgb, var(--warn) 12%, transparent); }
  .today-week { box-shadow: inset 0 -2px var(--accent); }
  .metric-heading {
    padding: 0.4rem;
    color: var(--dim);
    font-size: 0.72rem;
  }
  .day-group, .day-fill {
    background: var(--surface2);
    text-align: left;
    border-top: 1px solid var(--border-strong);
    border-bottom: 1px solid var(--border-strong);
  }
  .day-fill { padding: 0 0.75rem; color: var(--dim); }
  .day-heading {
    display: flex;
    align-items: center;
    gap: 0.15rem;
    padding: 0.2rem 0.45rem 0.2rem 0.7rem;
  }
  .day-title {
    flex: 1;
    line-height: 1.1;
    overflow-wrap: anywhere;
  }
  .day-title small {
    display: block;
    margin-top: 0.2rem;
    color: var(--dim);
    font-weight: 500;
  }
  .action {
    display: grid;
    place-items: center;
    padding: 0;
    flex: 0 0 1.75rem;
    width: 1.75rem;
    min-height: 1.75rem;
    border-radius: 0.25rem;
    color: var(--dim);
  }
  .action:hover, .action:focus-visible { background: var(--chip); color: var(--text); }
  .exercise {
    background: var(--surface);
    vertical-align: top;
    box-shadow: inset 3px 0 var(--group);
  }
  .exercise-action {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.35rem;
    width: 100%;
    min-height: 2.15rem;
    padding: 0.4rem 0.6rem 0.4rem 0.75rem;
    text-align: left;
    font-weight: 650;
  }
  .exercise-action span { overflow-wrap: anywhere; }
  .set {
    background: var(--surface);
    color: var(--dim);
    font-size: 0.76rem;
    font-variant-numeric: tabular-nums;
  }
  .first-set > * { border-top: 1px solid var(--border); }
  td { position: relative; height: 2.15rem; }
  .current-day { background: color-mix(in srgb, var(--accent) 10%, var(--surface)); }
  .cell, input, .dash {
    display: grid;
    place-items: center;
    width: 100%;
    min-height: 2.1rem;
    padding: 0;
    border: 0;
    font-variant-numeric: tabular-nums;
    text-align: center;
  }
  .cell:hover { background: var(--chip); }
  .cell:focus-visible, input:focus-visible, .exercise-action:focus-visible {
    outline-offset: -2px;
  }
  input {
    background: var(--surface2);
    color: var(--text);
  }
  input[aria-invalid="true"] { box-shadow: inset 0 0 0 2px var(--accent); }
  .unavailable { background: var(--surface2); }
  .dash { color: var(--dim); opacity: 0.7; }
  .with-action :is(.cell, input, .dash) { width: calc(100% - 1.2rem); }
  .target-action {
    position: absolute;
    top: 50%;
    right: 0;
    width: 1.2rem;
    transform: translateY(-50%);
  }
</style>
