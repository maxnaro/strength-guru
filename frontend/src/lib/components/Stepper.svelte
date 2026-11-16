<script lang="ts">
  export let value: number;
  export let min = 0;
  export let max = 500;
  export let step = 1;
  export let label = "";
</script>

<label class="stepper"
  ><span class="eyebrow">{label}</span><span class="stepper-row"
    ><button
      aria-label={`Decrease ${label}`}
      disabled={value <= min}
      on:click={() => (value = Math.max(min, +(value - step).toFixed(3)))}
      >−</button
    ><input
      aria-label={label}
      type="number"
      {min}
      {max}
      {step}
      bind:value
      on:change={() =>
        (value = Math.min(max, Math.max(min, Number(value) || 0)))}
    /><button
      aria-label={`Increase ${label}`}
      disabled={value >= max}
      on:click={() => (value = Math.min(max, +(value + step).toFixed(3)))}
      >+</button
    ></span
  ></label
>
