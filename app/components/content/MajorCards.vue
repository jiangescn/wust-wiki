<script setup lang="ts">
import BlurCard from '~/xupt/components/atomic/BlurCard.vue'
import XuptLink from '~/xupt/components/atomic/Link.vue'
import { majorColleges } from '~/data/majors'

const props = defineProps<{ college: keyof typeof majorColleges }>()
const group = computed(() => majorColleges[props.college])
const teachingBuilding = computed(() => (group.value as { teachingBuilding?: string } | undefined)?.teachingBuilding ?? '待核实')
</script>

<template>
  <div v-if="group" class="xupt-coder not-prose major-grid" :aria-label="group.name">
    <BlurCard v-for="major in group.majors" :key="major.name" :name="major.name" :tags="major.tags" flip class="major-card" tabindex="0" :aria-label="`${major.name}，翻面查看学院与官网`">
      <template #back>
        <div class="major-address"><small>所属学院</small><XuptLink :link="group.website" :text="group.name" /></div>
        <div class="major-address"><small>教学楼</small><span>{{ teachingBuilding }}</span></div>
        <XuptLink class="major-official" :link="major.url" :text="major.label" />
      </template>
    </BlurCard>
  </div>
</template>

<style scoped>
.major-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: .65rem;
  margin-block: 1.5rem;
}
.major-card { min-width: 0; min-height: 14rem; border-radius: .5rem; }
.major-card :deep(.face) { justify-content: center; padding: .75rem; font-size: .9rem; }
.major-card :deep(.banner) { display: none; }
.major-card :deep(.tag-line) { flex-grow: 0; }
.major-card :deep(.back) { gap: .65rem; padding: .65rem; font-size: .8rem; line-height: 1.5; }
.major-address { display: grid; gap: .2rem; }
.major-address small { color: var(--vp-c-text-2); }
.major-official { color: var(--vp-c-brand-1); }
@media (max-width: 1199px) {
  .major-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (max-width: 599px) {
  .major-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
/* Keep upstream hover animation; expose the same face to keyboard users. */
.major-card:focus-within :deep(.face) { transform: rotateY(180deg); }
.major-card:focus-within :deep(.back) { transform: rotateY(0); }
.major-card:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }
@media (prefers-reduced-motion: reduce) {
  .major-card :deep(.face), .major-card :deep(.back) { transition: none; }
}
</style>
