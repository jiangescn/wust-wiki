<script setup lang="ts">
const props = withDefaults(defineProps<{ rating: number | null; count?: number; countLabel?: string }>(), { countLabel: '人评分' })
const score = computed(() => props.rating === null ? null : Math.max(0, Math.min(5, props.rating)))
</script>

<template>
  <span class="food-rating">
    <span class="food-rating-main" :aria-label="score === null ? '暂无评分' : `${score.toFixed(1)} 分，满分 5 分`">
      <span class="food-rating-stars" aria-hidden="true">★★★★★<span :style="{ width: `${(score ?? 0) / 5 * 100}%` }">★★★★★</span></span>
      <strong v-if="score !== null" aria-hidden="true">{{ score.toFixed(1) }}</strong>
      <span v-else class="food-rating-empty" aria-hidden="true">暂无评分</span>
    </span>
    <small v-if="count !== undefined && score !== null">{{ count }} {{ countLabel }}</small>
  </span>
</template>

<style scoped>
.food-rating { display: inline-flex; flex-wrap: wrap; align-items: center; gap: .15rem .4rem; max-width: 100%; line-height: 1.5; }
.food-rating-main { display: inline-flex; align-items: center; flex-wrap: wrap; gap: .35rem; }
.food-rating-stars { position: relative; display: inline-block; color: var(--ui-text-dimmed); white-space: nowrap; font-family: Arial, sans-serif; font-size: 1rem; line-height: 1.2; letter-spacing: .04em; }
.food-rating-stars > span { position: absolute; inset: 0 auto 0 0; overflow: hidden; color: #b77900; }
:global(.dark) .food-rating-stars > span { color: #fbbf24; }
.food-rating strong { font-size: .9rem; color: var(--ui-text-highlighted); font-variant-numeric: tabular-nums; }
.food-rating small, .food-rating-empty { color: var(--ui-text-muted); font-size: .7rem; font-weight: 400; }
</style>
