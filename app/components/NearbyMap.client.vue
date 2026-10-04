<script setup lang="ts">
import { usePreferredReducedMotion } from '@vueuse/core'
import type { Map as LibreMap, GeoJSONSource, Marker, Popup } from 'maplibre-gl'
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { NearbyCampus, NearbyPlace } from '~/data/nearby'

const props = defineProps<{ places: NearbyPlace[], campuses: NearbyCampus[], selectedId: string | null, selectionRequest: number, overviewRequest: number }>()
const emit = defineEmits<{ select: [id: string] }>()
const container = ref<HTMLElement>()
const status = ref<'loading' | 'ready' | 'error'>('loading')
const moving = ref(false)
const settled = ref(false)
const mapTheme = ref<'light' | 'dark'>('light')
const reducedMotion = usePreferredReducedMotion()
const styleUrl = computed(() => `https://tiles.openfreemap.org/styles/${mapTheme.value === 'dark' ? 'dark' : 'liberty'}`)
const themeLabel = computed(() => mapTheme.value === 'light' ? '切换为深色地图' : '切换为亮色地图')
let map: LibreMap | undefined
let sdk: typeof import('maplibre-gl') | undefined
let popup: Popup | undefined
let campusMarkers: { id: string, marker: Marker, button: HTMLButtonElement }[] = []
let resizeObserver: ResizeObserver | undefined
let timer: ReturnType<typeof setTimeout> | undefined
let generation = 0
let alive = false
let initialViewSet = false

function data() {
  return { type: 'FeatureCollection' as const, features: props.places.map(place => ({ type: 'Feature' as const, geometry: { type: 'Point' as const, coordinates: place.coordinates }, properties: { id: place.id, name: place.name } })) }
}
function colors() {
  return mapTheme.value === 'dark'
    ? { primary: '#60a5fa', surface: '#1b1b1f' }
    : { primary: '#2563eb', surface: '#ffffff' }
}
function updateSelection() {
  campusMarkers.forEach(({ id, button }) => button.setAttribute('aria-pressed', String(id === props.selectedId)))
  if (!map?.getLayer('nearby-points')) return
  map.setPaintProperty('nearby-points', 'circle-radius', ['case', ['==', ['get', 'id'], props.selectedId ?? ''], 10, 6])
}
function showSelected(animate = true) {
  if (!map || !sdk || !map.getLayer('nearby-points')) return
  popup?.remove()
  map.stop()
  const place = [...props.campuses, ...props.places].find(item => item.id === props.selectedId)
  if (!place) return
  map.flyTo({ center: place.coordinates, zoom: place.zoom, duration: animate && reducedMotion.value !== 'reduce' ? 1100 : 0, essential: false })
  popup = new sdk.Popup({ closeButton: false, offset: 14, maxWidth: '220px' }).setLngLat(place.coordinates).setText(place.name).addTo(map)
}
function fitOverview(animate = true) {
  if (!map || !sdk || !map.getLayer('nearby-points')) return
  const places = [...props.campuses, ...props.places]
  if (!places.length) return
  popup?.remove()
  map.stop()
  const bounds = new sdk.LngLatBounds()
  places.forEach(place => bounds.extend(place.coordinates))
  map.fitBounds(bounds, { padding: 48, maxZoom: 14, duration: animate && reducedMotion.value !== 'reduce' ? 850 : 0, essential: false })
}
function addLayers() {
  if (!map) return
  const palette = colors()
  map.addSource('nearby', { type: 'geojson', data: data(), cluster: true, clusterMaxZoom: 12, clusterRadius: 36 })
  map.addLayer({ id: 'nearby-clusters', type: 'circle', source: 'nearby', filter: ['has', 'point_count'], paint: { 'circle-color': palette.primary, 'circle-radius': ['step', ['get', 'point_count'], 16, 20, 20, 100, 25] } })
  map.addLayer({ id: 'nearby-counts', type: 'symbol', source: 'nearby', filter: ['has', 'point_count'], layout: { 'text-field': ['get', 'point_count_abbreviated'], 'text-font': ['Noto Sans Regular'], 'text-size': 12 }, paint: { 'text-color': palette.surface } })
  map.addLayer({ id: 'nearby-points', type: 'circle', source: 'nearby', filter: ['!', ['has', 'point_count']], paint: { 'circle-color': palette.primary, 'circle-radius': 6, 'circle-stroke-width': 2, 'circle-stroke-color': palette.surface } })
  updateSelection()
  if (!initialViewSet) {
    initialViewSet = true
    if (props.selectedId) showSelected(false)
    else fitOverview(false)
  }
}
function addCampusMarkers(instance: LibreMap) {
  campusMarkers = props.campuses.map(campus => {
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'nearby-campus-marker'
    button.dataset.campusId = campus.id
    button.title = campus.name
    button.setAttribute('aria-label', campus.name)
    button.setAttribute('aria-pressed', String(campus.id === props.selectedId))
    const label = document.createElement('span')
    label.className = 'nearby-campus-marker-label'
    const school = document.createElement('span')
    school.className = 'nearby-campus-marker-school'
    school.textContent = '武科大'
    const name = document.createElement('span')
    name.textContent = campus.label.replace('校区', '')
    label.append(school, name)
    button.append(label)
    button.addEventListener('click', event => {
      event.stopPropagation()
      emit('select', campus.id)
    })
    const marker = new sdk!.Marker({ element: button, anchor: 'center' }).setLngLat(campus.coordinates).addTo(instance)
    return { id: campus.id, marker, button }
  })
}
function dispose() {
  clearTimeout(timer)
  resizeObserver?.disconnect()
  popup?.remove()
  campusMarkers.forEach(({ marker }) => marker.remove())
  campusMarkers = []
  map?.remove()
  map = undefined
  initialViewSet = false
  moving.value = false
  settled.value = false
}
async function initialize() {
  const current = ++generation
  dispose()
  status.value = 'loading'
  try {
    sdk = await import('maplibre-gl')
    if (!alive || current !== generation || !container.value) return
    sdk.setWorkerUrl(workerUrl)
    const instance = new sdk.Map({ container: container.value, style: styleUrl.value, center: [114.34, 30.57], zoom: 11, attributionControl: false })
    map = instance
    addCampusMarkers(instance)
    instance.addControl(new sdk.NavigationControl({ showCompass: false }), 'top-right')
    instance.addControl(new sdk.AttributionControl({ compact: true }), 'bottom-right')
    instance.once('load', () => {
      // MapLibre 6 starts compact attribution expanded; retain its native toggle.
      const attribution = instance.getContainer().querySelector<HTMLDetailsElement>('.maplibregl-ctrl-attrib')
      attribution?.classList.remove('maplibregl-compact-show')
      attribution?.removeAttribute('open')
    })
    instance.on('style.load', () => {
      if (map !== instance) return
      addLayers()
    })
    instance.on('idle', () => {
      if (map === instance && instance.getLayer('nearby-points')) {
        clearTimeout(timer)
        status.value = 'ready'
        settled.value = true
      }
    })
    instance.on('dataloading', () => { settled.value = false })
    instance.on('error', () => { if (map === instance && status.value === 'loading') status.value = 'error' })
    instance.on('movestart', () => { moving.value = true; settled.value = false })
    instance.on('moveend', () => { moving.value = false })
    instance.on('click', 'nearby-points', event => {
      const id = event.features?.[0]?.properties?.id
      if (typeof id === 'string') emit('select', id)
    })
    instance.on('click', 'nearby-clusters', async event => {
      const feature = event.features?.[0]
      if (!feature || feature.geometry.type !== 'Point') return
      try {
        const source = instance.getSource('nearby') as GeoJSONSource
        const zoom = await source.getClusterExpansionZoom(Number(feature.properties?.cluster_id))
        if (map !== instance) return
        instance.stop()
        instance.easeTo({ center: feature.geometry.coordinates as [number, number], zoom, duration: reducedMotion.value === 'reduce' ? 0 : 650, essential: false })
      } catch { /* A theme switch can replace the source during expansion. */ }
    })
    for (const layer of ['nearby-points', 'nearby-clusters']) {
      instance.on('mouseenter', layer, () => { instance.getCanvas().style.cursor = 'pointer' })
      instance.on('mouseleave', layer, () => { instance.getCanvas().style.cursor = '' })
    }
    resizeObserver = new ResizeObserver(() => instance.resize())
    resizeObserver.observe(container.value)
    timer = setTimeout(() => { if (map === instance && !instance.areTilesLoaded()) status.value = 'error' }, 20000)
  } catch { if (alive && current === generation) status.value = 'error' }
}
watch(() => [props.selectedId, props.selectionRequest], () => { updateSelection(); showSelected() })
watch(() => props.places, () => {
  const source = map?.getSource('nearby') as GeoJSONSource | undefined
  source?.setData(data())
  if (!props.selectedId) popup?.remove()
})
watch(() => props.overviewRequest, () => fitOverview())
watch(styleUrl, url => {
  if (!map) return
  status.value = 'loading'
  settled.value = false
  map.setStyle(url)
})
watch(reducedMotion, value => { if (value === 'reduce') map?.stop() })
onMounted(() => { alive = true; initialize() })
onBeforeUnmount(() => { alive = false; generation++; dispose() })
</script>

<template>
  <div class="nearby-map" :data-map-theme="mapTheme" :data-map-state="status" :data-map-moving="moving" :data-map-settled="settled">
    <div ref="container" class="nearby-canvas" role="region" aria-label="武汉去处地图" />
    <button type="button" class="nearby-map-theme" :title="themeLabel" :aria-label="themeLabel" @click="mapTheme = mapTheme === 'light' ? 'dark' : 'light'">
      <UIcon :name="mapTheme === 'light' ? 'i-lucide-moon' : 'i-lucide-sun'" aria-hidden="true" />
    </button>
    <div v-if="status !== 'ready'" class="nearby-map-state" role="status">
      <span>{{ status === 'loading' ? '地图加载中' : '地图暂时无法加载' }}</span>
      <UButton v-if="status === 'error'" size="sm" color="neutral" variant="outline" @click="initialize">重试</UButton>
    </div>
  </div>
</template>

<style scoped>
.nearby-map { --nearby-map-bg: #fff; --nearby-map-text: #18181b; position: relative; height: 440px; overflow: hidden; border: 1px solid var(--ui-border); border-radius: .75rem; background: var(--nearby-map-bg); }
.nearby-map[data-map-theme="dark"] { --nearby-map-bg: #1b1b1f; --nearby-map-text: #f4f4f5; }
.nearby-canvas { width: 100%; height: 100%; }
.nearby-map-theme { position: absolute; top: 80px; right: 10px; z-index: 2; display: grid; place-items: center; width: 29px; height: 29px; padding: 0; border: 0; border-radius: 4px; background: #fff; color: #333; box-shadow: 0 0 0 2px #0000001a; font-size: 16px; cursor: pointer; }
.nearby-map-theme:hover { background: #f2f2f2; }
.nearby-map-theme:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
.nearby-map-state { position: absolute; inset: 0; z-index: 3; display: flex; align-items: center; justify-content: center; gap: .75rem; background: var(--ui-bg-muted); color: var(--ui-text-muted); font-size: .875rem; }
:deep(.nearby-campus-marker) { width: 18px; height: 18px; padding: 0; border: 3px solid var(--nearby-map-bg); border-radius: 50%; background: #2563eb; box-shadow: 0 0 0 1px #2563eb, 0 2px 5px #0002; cursor: pointer; z-index: 1; }
:deep(.nearby-campus-marker-label) { position: absolute; top: 50%; left: calc(100% + 7px); translate: 0 -50%; display: flex; align-items: center; gap: 6px; padding: 5px 9px; border: 1px solid #2563eb33; border-radius: 999px; background: var(--nearby-map-bg); color: var(--nearby-map-text); box-shadow: 0 2px 6px #00000014; font: 500 12px/1.3 var(--font-sans); white-space: nowrap; pointer-events: none; }
:deep(.nearby-campus-marker-school) { padding-right: 6px; border-right: 1px solid #2563eb33; color: #2563eb; font-weight: 600; }
:deep(.nearby-campus-marker[aria-pressed="true"]) { box-shadow: 0 0 0 1px #2563eb, 0 0 0 5px #2563eb26; }
:deep(.nearby-campus-marker[aria-pressed="true"] .nearby-campus-marker-label) { border-color: #2563eb; }
.nearby-map[data-map-theme="dark"] :deep(.nearby-campus-marker-school) { color: #93c5fd; }
:deep(.nearby-campus-marker:focus-visible) { outline: 2px solid #2563eb; outline-offset: 5px; }
:deep(.maplibregl-popup) { z-index: 2; }
:deep(.maplibregl-popup-content) { background: var(--nearby-map-bg); color: var(--nearby-map-text); font: .8rem/1.5 var(--font-sans); padding: .5rem .75rem; border-radius: .375rem; }
:deep(.maplibregl-popup-anchor-bottom .maplibregl-popup-tip) { border-top-color: var(--nearby-map-bg); }
:deep(.maplibregl-popup-anchor-top .maplibregl-popup-tip) { border-bottom-color: var(--nearby-map-bg); }
:deep(.maplibregl-popup-anchor-left .maplibregl-popup-tip) { border-right-color: var(--nearby-map-bg); }
:deep(.maplibregl-popup-anchor-right .maplibregl-popup-tip) { border-left-color: var(--nearby-map-bg); }
@media (max-width: 640px) { .nearby-map { height: 320px; } }
</style>
