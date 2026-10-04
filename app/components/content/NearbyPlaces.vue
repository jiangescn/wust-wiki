<script setup lang="ts">
import { nearbyDefaultCampuses as nearbyCampuses, nearbyPlaces } from '~/data/nearby'

const query = ref('')
const category = ref('全部')
const selectedId = ref<string | null>(null)
const selectionRequest = ref(0)
const overviewRequest = ref(0)
const categories = ['全部', ...new Set(nearbyPlaces.map(place => place.category))]
const filteredPlaces = computed(() => {
  const words = query.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean)
  return nearbyPlaces.filter(place => (category.value === '全部' || place.category === category.value)
    && words.every(word => `${place.name} ${place.category} ${place.area}`.toLocaleLowerCase().includes(word)))
})
const selected = computed(() => [...nearbyCampuses, ...nearbyPlaces].find(place => place.id === selectedId.value))
watch(filteredPlaces, places => {
  if (!nearbyCampuses.some(place => place.id === selectedId.value) && !places.some(place => place.id === selectedId.value)) selectedId.value = null
})
function overview() {
  selectedId.value = null
  overviewRequest.value++
}
function select(id: string) {
  selectedId.value = id
  selectionRequest.value++
}
</script>

<template>
  <section class="nearby-places not-prose" aria-label="周边去处地图">
    <div class="nearby-toolbar">
      <UInput v-model="query" class="nearby-search" icon="i-lucide-search" placeholder="搜索地点" aria-label="搜索地点" autocomplete="off" />
      <select v-model="category" class="nearby-category" aria-label="地点分类">
        <option v-for="item in categories" :key="item">{{ item }}</option>
      </select>
      <UButton color="neutral" variant="outline" size="sm" @click="overview">查看全部</UButton>
    </div>
    <div class="nearby-layout">
      <div class="nearby-map-panel">
        <ClientOnly>
          <NearbyMap :places="filteredPlaces" :campuses="nearbyCampuses" :selected-id="selectedId" :selection-request="selectionRequest" :overview-request="overviewRequest" @select="select" />
          <template #fallback><div class="nearby-placeholder">地图加载中</div></template>
        </ClientOnly>
        <div class="nearby-selection" aria-live="polite">
          <template v-if="selected">
            <div><strong>{{ selected.name }}</strong><span>{{ selected.area }} · {{ selected.category }}</span></div>
            <a :href="selected.source" target="_blank" rel="noopener noreferrer">参考位置 ↗</a>
          </template>
          <template v-else><span>{{ filteredPlaces.length }} 个去处 · {{ nearbyCampuses.length }} 个校区</span><span>参考位置</span></template>
        </div>
      </div>
      <div class="nearby-directory">
        <div class="nearby-campuses" role="group" aria-label="武汉科技大学校区">
          <div class="nearby-campus-heading">武汉科技大学</div>
          <div class="nearby-campus-list">
            <button v-for="campus in nearbyCampuses" :key="campus.id" type="button" class="nearby-campus nearby-choice" :data-place-id="campus.id" :aria-pressed="selectedId === campus.id" @click="select(campus.id)">{{ campus.label }}</button>
          </div>
        </div>
        <div class="nearby-list" role="group" aria-label="地点列表">
          <button v-for="place in filteredPlaces" :key="place.id" type="button" class="nearby-place nearby-choice" :data-place-id="place.id" :aria-pressed="selectedId === place.id" @click="select(place.id)">
            <strong>{{ place.name }}</strong><span>{{ place.area }} · {{ place.category }}</span>
          </button>
          <div v-if="!filteredPlaces.length" class="nearby-empty">没有匹配的地点</div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.nearby-places { font: .875rem/1.5 var(--font-sans); color: var(--ui-text); margin-bottom: 1.5rem; }
.nearby-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; margin-bottom: .75rem; }
.nearby-search { flex: 1 1 10rem; min-width: 0; }
.nearby-category { height: 2rem; min-width: 6rem; border: 1px solid var(--ui-border-accented); border-radius: .375rem; padding: 0 .5rem; font: inherit; color: var(--ui-text); background: var(--ui-bg); }
.nearby-layout { display: grid; grid-template-columns: minmax(0, 1fr) minmax(11rem, 32%); gap: .75rem; }
.nearby-map-panel { min-width: 0; }
.nearby-placeholder { display: grid; place-items: center; height: 440px; border-radius: .75rem; background: var(--ui-bg-muted); color: var(--ui-text-muted); }
.nearby-selection { min-height: 3rem; display: flex; align-items: center; justify-content: space-between; gap: .5rem; font-size: .75rem; color: var(--ui-text-muted); padding: .5rem .125rem; }
.nearby-selection strong { color: var(--ui-text-highlighted); font-size: .875rem; margin-right: .5rem; background: none; }
.nearby-selection a { white-space: nowrap; color: var(--ui-primary); }
.nearby-directory { display: flex; flex-direction: column; height: 440px; min-width: 0; gap: .6rem; }
.nearby-campuses { flex-shrink: 0; padding: .6rem; border: 1px solid var(--ui-border); border-radius: .6rem; background: var(--ui-bg); }
.nearby-campus-heading { display: flex; align-items: center; gap: .4rem; font-weight: 600; color: var(--ui-text-highlighted); margin-bottom: .5rem; }
.nearby-campus-heading::before { content: ''; width: .4rem; height: .4rem; border-radius: 50%; background: var(--ui-primary); }
.nearby-campus-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .35rem; }
.nearby-campus { padding: .3rem .4rem; min-height: 2rem; border: 1px solid transparent; border-radius: .35rem; font: inherit; font-size: .75rem; text-align: center; color: var(--ui-text); background: var(--ui-bg-muted); cursor: pointer; }
.nearby-campus:hover, .nearby-campus[aria-pressed="true"] { color: var(--ui-primary); background: color-mix(in srgb, var(--ui-primary) 8%, var(--ui-bg)); border-color: color-mix(in srgb, var(--ui-primary) 30%, var(--ui-border)); }
.nearby-campus:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 1px; }
.nearby-list { display: flex; flex: 1; min-height: 0; flex-direction: column; gap: .35rem; overflow-y: auto; overscroll-behavior: contain; scrollbar-width: thin; padding: 3px; }
.nearby-place { display: flex; flex-direction: column; flex-shrink: 0; gap: .2rem; text-align: left; width: 100%; min-height: 3.5rem; padding: .6rem .7rem; font: inherit; color: var(--ui-text); border: 1px solid transparent; border-radius: .5rem; background: var(--ui-bg); cursor: pointer; transition: background .15s, border-color .15s; }
.nearby-place strong { font: inherit; font-weight: 600; color: var(--ui-text-highlighted); background: none; }
.nearby-place span { font-size: .75rem; color: var(--ui-text-muted); }
.nearby-place:hover { background: var(--ui-bg-elevated); }
.nearby-place[aria-pressed="true"] { background: color-mix(in srgb, var(--ui-primary) 8%, var(--ui-bg)); border-color: color-mix(in srgb, var(--ui-primary) 45%, var(--ui-border)); }
.nearby-place:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 1px; }
.nearby-empty { padding: 1rem .5rem; color: var(--ui-text-muted); }
@media (max-width: 640px) {
  .nearby-layout { grid-template-columns: minmax(0, 1fr); gap: .25rem; }
  .nearby-placeholder { height: 320px; }
  .nearby-directory { height: auto; }
  .nearby-campus { text-align: center; padding-inline: .2rem; }
  .nearby-list { display: grid; flex: none; grid-template-columns: repeat(2, minmax(0, 1fr)); max-height: 18rem; }
  .nearby-place { padding: .55rem; }
  .nearby-selection strong, .nearby-selection span { display: inline-block; }
}
@media (prefers-reduced-motion: reduce) { .nearby-place { transition: none; } }
</style>
