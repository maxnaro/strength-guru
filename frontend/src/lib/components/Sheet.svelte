<script lang="ts">
  import { onMount } from "svelte";
  export let title = "";
  export let close: () => void;
  export let wide = false;
  let dialog: HTMLDialogElement;
  onMount(() => {
    dialog.showModal();
    return () => dialog.close();
  });
</script>

<dialog
  bind:this={dialog}
  class:wide
  on:cancel={(e) => {
    e.preventDefault();
    close();
  }}
  on:click={(e) => {
    if (e.target === dialog) close();
  }}
  aria-label={title}
>
  <section class="sheet">
    <div class="handle"></div>
    <header>
      <h2>{title}</h2>
      <button class="icon" aria-label="Close dialog" on:click={close}>✕</button>
    </header>
    <slot />
  </section>
</dialog>
