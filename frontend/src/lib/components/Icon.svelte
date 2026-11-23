<script lang="ts">
  import { materialIcons } from "./material-icons";
  export let name: keyof typeof materialIcons;
  export let size = 22;
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="currentColor"
  aria-hidden="true"
  focusable="false"
>
  {#each materialIcons[name] as path}
    <path d={path} />
  {/each}
</svg>

<style>
  svg {
    flex-shrink: 0;
    vertical-align: middle;
  }
</style>
