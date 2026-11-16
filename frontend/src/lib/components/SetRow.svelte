<script lang="ts">
  import Stepper from "./Stepper.svelte";
  import type { Row } from "$lib/domain/training";
  export let index: number;
  export let reps: number;
  export let rir: number;
  export let entry: Row | undefined;
  export let recent: Row | undefined;
  export let suggestion: Row | undefined;
  export let active = false;
  export let activate: () => void;
  export let save: (w: number | null, r: number, ri: number) => Promise<void>;
  let weight: number;
  let count: number;
  let reserve: number;
  let picking = false;
  let initialized = false;
  let busy = false;
  let validationError = "";
  $: if (active && !initialized) {
    weight = entry?.weight ?? recent?.weight ?? suggestion?.weight ?? 0;
    count = entry?.reps ?? recent?.reps ?? suggestion?.reps ?? reps;
    reserve = entry?.rir ?? recent?.rir ?? suggestion?.rir ?? rir;
    initialized = true;
  }
  async function log() {
    validationError = "";
    if (!Number.isFinite(weight) || weight < 0 || weight > 500) {
      validationError = "Enter a weight between 0 and 500 kg.";
      return;
    }
    if (!Number.isInteger(count) || count < 1 || count > 50) {
      validationError = "Enter a whole number of reps between 1 and 50.";
      return;
    }
    busy = true;
    try {
      await save(weight, count, reserve);
    } finally {
      busy = false;
    }
  }
</script>

{#if active}
  <div class="active-set">
    {#if validationError}<p class="warning" role="alert">{validationError}</p>{/if}
    <div class="row">
      <span class="set-number">{index + 1}</span><strong>Set {index + 1}</strong
      ><span class="eyebrow push">TARGET {reps} reps · RIR {rir}</span>
    </div>
    {#if suggestion}<p class="hint">
        Last: {suggestion.weight ?? "—"}kg × {suggestion.reps ?? "—"} · RIR {suggestion.rir ??
          "—"}
      </p>{/if}
    <div class="two">
      <Stepper
        bind:value={weight}
        min={0}
        max={500}
        step={2.5}
        label="WEIGHT (KG)"
      /><Stepper bind:value={count} min={1} max={50} label="REPS" />
    </div>
    {#if picking}<p class="eyebrow">ADJUST RIR</p>
      <div class="rir-picker">
        {#each [0, 1, 2, 3, 4, 5] as r}<button
            class:selected={r === reserve}
            on:click={() => {
              reserve = r;
              picking = false;
            }}
            >{r}{#if r === rir}<small>PLAN</small>{/if}</button
          >{/each}
      </div>
    {:else}<div class="row">
        <button class="soft" on:click={() => (picking = true)}
          >Adjust RIR</button
        ><button class="group-button grow" disabled={busy} on:click={log}
          >{busy ? "Saving…" : "Log set"}
          <span class="mini">RIR {reserve}</span></button
        >
      </div>{/if}
  </div>
{:else if entry}
  <button
    class="saved-set row full"
    on:click={() => {
      initialized = false;
      activate();
    }}
    aria-label={`Edit saved set ${index + 1}`}
    ><span class="set-number success">{index + 1}</span><span
      ><small>KG</small><b>{entry.weight ?? "—"}</b></span
    ><span><small>REPS</small><b>{entry.reps ?? "—"}</b></span><span
      class:warning={entry.rir != null && entry.rir < rir}
      ><small>RIR</small><b>{entry.rir ?? "—"}</b></span
    ><span class="push muted">✎</span></button
  >
{:else}<button
    class="inactive-set row full"
    on:click={() => {
      initialized = false;
      activate();
    }}
    ><span class="set-number">{index + 1}</span><span>Set {index + 1}</span
    ><span class="eyebrow push">{reps} REPS · RIR {rir}</span></button
  >{/if}
