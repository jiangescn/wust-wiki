<script setup lang="ts">
// Adapted from Zhilu's blog-v3 Folding.vue (MIT). Native details preserves keyboard support.
defineProps<{ title: string; open?: boolean }>()
</script>

<template>
  <details class="wiki-folding" :open="open">
    <summary><slot name="title">{{ title }}</slot></summary>
    <div class="wiki-folding-body"><slot /></div>
  </details>
</template>
