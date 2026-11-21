<script setup lang="ts">
defineProps<{ title?: string }>()
</script>

<template>
  <section class="article">
    <h2 v-if="title">{{ title }}</h2>
    <slot />
  </section>
</template>
