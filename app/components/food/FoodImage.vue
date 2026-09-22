<script setup lang="ts">
const props = defineProps<{ src?: string; alt: string }>()
const failed = ref(false)
watch(() => props.src, () => { failed.value = false })
</script>

<template>
  <span class="food-image">
    <img v-if="src && !failed" :src="src" :alt="alt" loading="lazy" decoding="async" @error="failed = true">
    <span v-else class="food-image-empty" aria-label="暂无图片"><UIcon name="i-lucide-utensils" aria-hidden="true" /></span>
  </span>
</template>

<style scoped>
.food-image { position: relative; display: block; width: 100%; aspect-ratio: 4 / 3; overflow: hidden; background: var(--ui-bg-muted); border-radius: .5rem; }
.food-image img { position: absolute; inset: 0; display: block; width: 100%; height: 100%; margin: 0; object-fit: cover; }
.food-image-empty { position: absolute; inset: 0; display: grid; place-items: center; color: var(--ui-text-dimmed); font-size: 1.75rem; }
</style>
