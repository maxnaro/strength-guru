<script lang="ts">
  export let name: "flame" | "dumbbell" | "repeat";
  export let size = 22;
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="1.8"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if name === "flame"}
    <path
      d="M12 3c.6 4.2-4.5 4.8-4.5 8.2-1.3-.7-1.9-1.7-2-3C2 12.7 4.1 21 12 21c5.3 0 8-3.7 8-7.3 0-3.2-2.3-6.5-4.4-8.1.2 2.7-.8 3.7-1.7 4.1.2-2.5-.4-4.9-1.9-6.7Z"
    />
    <path
      d="M12 13c-2.2 2.2-3.6 3.3-2.3 5.2 1.5 2 4.6 1.1 4.6-1.2 0-1.5-1.2-2.4-2.3-4Z"
    />
  {:else if name === "dumbbell"}
    <path
      d="m7 7 10 10M4 5l1-1 3 3-1 1-3-3Zm12 12 1-1 3 3-1 1-3-3ZM2 8l6-6m8 20 6-6M4 10l6-6m4 16 6-6M6 12l6-6m0 12 6-6"
    />
  {:else}
    <path
      d="M20 7H8a5 5 0 0 0-5 5v2m14-10 3 3-3 3M4 17h12a5 5 0 0 0 5-5v-2M7 20l-3-3 3-3"
    />
  {/if}
</svg>
