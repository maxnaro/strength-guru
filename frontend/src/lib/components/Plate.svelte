<script lang="ts">
  export let label = "";
  export let small = false;
  $: words = label
    .trim()
    .split(/[\s&]+/)
    .filter(Boolean);
  $: text =
    label.length <= 4
      ? label
      : words.length === 1
        ? `${label.slice(0, 3)}-`
        : words
            .map((w) => w[0])
            .join("")
            .slice(0, 4);
</script>

<div class="plate" class:small aria-hidden="true">{text.toUpperCase()}</div>
