<script setup lang="ts">
import type { Object3D } from 'three'
import { fetchCampusResource, parseCampusManifest } from '~/utils/campus-model'

const manifestUrl = useRuntimeConfig().public.campusManifestUrl
const modelLabel = manifestUrl ? '黄家湖校区' : '教一楼'
const progress = ref('')
const loadedParts = ref(0)

const shell = ref<HTMLElement>()
const container = ref<HTMLElement>()
const status = ref<'idle' | 'loading' | 'ready' | 'error'>(manifestUrl ? 'idle' : 'loading')
const fullscreen = ref(false)
const fullscreenAvailable = ref(false)
let alive = false
let generation = 0
let controller: AbortController | undefined
let disposeCurrent = () => {}
let resetView = () => {}

async function initialize() {
  const current = ++generation
  controller?.abort()
  disposeCurrent()
  disposeCurrent = () => {}
  resetView = () => {}
  loadedParts.value = 0
  progress.value = ''
  status.value = 'loading'
  const request = new AbortController()
  controller = request
  const resources: (() => void)[] = []
  let closed = false
  const dispose = () => {
    if (closed) return
    closed = true
    resources.splice(0).reverse().forEach(release => release())
  }
  disposeCurrent = dispose

  try {
    const [THREE, { GLTFLoader }, { OrbitControls }, { RoomEnvironment }] = await Promise.all([
      import('three'),
      import('three/addons/loaders/GLTFLoader.js'),
      import('three/addons/controls/OrbitControls.js'),
      import('three/addons/environments/RoomEnvironment.js')
    ])
    if (!alive || current !== generation) return

    const model = new THREE.Group()
    const releaseModel = (root: Object3D) => {
      const geometries = new Set<import('three').BufferGeometry>()
      const materials = new Set<import('three').Material>()
      const textures = new Set<import('three').Texture>()
      root.traverse(object => {
        if (!(object instanceof THREE.Mesh)) return
        if (object instanceof THREE.InstancedMesh) object.dispose()
        geometries.add(object.geometry)
        for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
          materials.add(material)
          for (const value of Object.values(material)) {
            if (value instanceof THREE.Texture) textures.add(value)
          }
        }
      })
      textures.forEach(texture => {
        const image: unknown = texture.source.data
        if (image instanceof ImageBitmap) image.close()
        texture.dispose()
      })
      materials.forEach(material => material.dispose())
      geometries.forEach(geometry => geometry.dispose())
    }
    resources.push(() => releaseModel(model))
    const host = container.value
    if (!alive || current !== generation || !host) return
    let parts = [{ url: new URL('/models/campus/teach1.glb', location.href).href, bytes: 0 }]
    if (manifestUrl) {
      const absoluteManifest = new URL(manifestUrl, location.href).href
      const manifestBytes = await fetchCampusResource(absoluteManifest, request.signal)
      const manifest = parseCampusManifest(JSON.parse(new TextDecoder().decode(manifestBytes)), absoluteManifest)
      parts = manifest.parts
    }
    if (!alive || current !== generation || request.signal.aborted) return
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, logarithmicDepthBuffer: true })
    resources.push(() => {
      renderer.dispose()
      renderer.forceContextLoss()
      renderer.domElement.remove()
    })
    renderer.setPixelRatio(window.devicePixelRatio || 1)
    renderer.outputColorSpace = THREE.SRGBColorSpace
    renderer.toneMapping = THREE.ACESFilmicToneMapping
    renderer.toneMappingExposure = 1
    renderer.domElement.tabIndex = 0
    renderer.domElement.setAttribute('aria-label', `${modelLabel}三维模型，可拖动旋转、滚轮缩放或使用方向键`)
    host.append(renderer.domElement)

    const scene = new THREE.Scene()
    const environment = new RoomEnvironment()
    const generator = new THREE.PMREMGenerator(renderer)
    const environmentMap = generator.fromScene(environment, 0.04)
    resources.push(() => environmentMap.dispose())
    environment.dispose()
    generator.dispose()
    scene.environment = environmentMap.texture
    scene.environmentIntensity = 1
    scene.add(model)

    const bounds = new THREE.Box3()
    const center = new THREE.Vector3()
    const sphere = new THREE.Sphere(center, 1)
    const camera = new THREE.PerspectiveCamera(38, 1, 0.01, 40)
    const controls = new OrbitControls(camera, renderer.domElement)
    controls.target.copy(center)
    controls.enableDamping = false
    controls.minDistance = sphere.radius * 0.03
    controls.maxDistance = sphere.radius * 12
    controls.maxPolarAngle = Math.PI * 0.49
    controls.listenToKeyEvents(renderer.domElement)
    let frame = 0
    let viewAdjusted = false
    const keepView = () => { viewAdjusted = true }

    function render() {
      if (closed || frame) return
      frame = requestAnimationFrame(() => {
        frame = 0
        if (!closed) renderer.render(scene, camera)
      })
    }
    function fit() {
      if (!loadedParts.value) return
      const vertical = THREE.MathUtils.degToRad(camera.fov)
      const horizontal = 2 * Math.atan(Math.tan(vertical / 2) * camera.aspect)
      const distance = sphere.radius / Math.sin(Math.min(vertical, horizontal) / 2) * 1.08
      camera.position.copy(center).add(new THREE.Vector3(-1, 0.7, 1).normalize().multiplyScalar(distance))
      controls.target.copy(center)
      controls.update()
      render()
    }
    const resize = () => {
      if (closed) return
      const { width, height } = host.getBoundingClientRect()
      if (!width || !height) return
      camera.aspect = width / height
      camera.updateProjectionMatrix()
      renderer.setSize(width, height)
      render()
    }
    function contextLost(event: Event) {
      event.preventDefault()
      if (alive && current === generation) {
        request.abort()
        status.value = 'error'
        loadedParts.value = 0
        disposeCurrent()
      }
    }
    const observer = new ResizeObserver(resize)
    resources.push(() => {
      cancelAnimationFrame(frame)
      observer.disconnect()
      controls.removeEventListener('change', render)
      controls.removeEventListener('start', keepView)
      controls.stopListenToKeyEvents()
      controls.dispose()
      renderer.domElement.removeEventListener('webglcontextlost', contextLost)
      scene.environment = null
    })
    resetView = fit
    controls.addEventListener('change', render)
    controls.addEventListener('start', keepView)
    renderer.domElement.addEventListener('webglcontextlost', contextLost)
    observer.observe(host)
    resize()
    const loader = new GLTFLoader()
    for (const [index, part] of parts.entries()) {
      progress.value = `已加载 ${index}/${parts.length}`
      const bytes = await fetchCampusResource(part.url, request.signal)
      if (part.bytes && bytes.byteLength !== part.bytes) throw new Error('模型分块大小与清单不符')
      const gltf = await loader.parseAsync(bytes, new URL('.', part.url).href)
      if (!alive || current !== generation || request.signal.aborted || closed) {
        releaseModel(gltf.scene)
        return
      }
      model.add(gltf.scene)
      bounds.union(new THREE.Box3().setFromObject(gltf.scene))
      bounds.getBoundingSphere(sphere)
      if (!Number.isFinite(sphere.radius) || sphere.radius <= 0) throw new Error('Model has no visible geometry')
      loadedParts.value = index + 1
      progress.value = `已加载 ${index + 1}/${parts.length}`
      camera.near = Math.max(sphere.radius / 10000, 0.001)
      camera.far = sphere.radius * 40
      camera.updateProjectionMatrix()
      controls.minDistance = sphere.radius * 0.03
      controls.maxDistance = sphere.radius * 12
      if (!viewAdjusted) fit()
      render()
      await new Promise<void>(resolve => requestAnimationFrame(() => resolve()))
      if (!alive || current !== generation || request.signal.aborted || closed) return
    }
    status.value = 'ready'
  } catch {
    if (!alive || current !== generation || !loadedParts.value) dispose()
    if (alive && current === generation) {
      status.value = 'error'
    }
  }
}

function reset() {
  resetView()
}
async function toggleFullscreen() {
  try {
    if (document.fullscreenElement === shell.value) await document.exitFullscreen()
    else await shell.value?.requestFullscreen()
  } catch {
    updateFullscreen()
  }
}
function updateFullscreen() {
  fullscreen.value = document.fullscreenElement === shell.value
}
onMounted(() => {
  alive = true
  fullscreenAvailable.value = document.fullscreenEnabled
  document.addEventListener('fullscreenchange', updateFullscreen)
  if (!manifestUrl) initialize()
})
onBeforeUnmount(() => {
  alive = false
  generation++
  controller?.abort()
  document.removeEventListener('fullscreenchange', updateFullscreen)
  disposeCurrent()
})
</script>

<template>
  <div ref="shell" class="campus-scene" :data-model-state="status" :data-loaded-parts="loadedParts">
    <div class="campus-toolbar">
      <UButton color="neutral" variant="outline" size="sm" :disabled="!loadedParts" @click="reset">重置视角</UButton>
      <UButton v-if="fullscreenAvailable" color="neutral" variant="outline" size="sm" @click="toggleFullscreen">{{ fullscreen ? '退出全屏' : '全屏' }}</UButton>
    </div>
    <div class="campus-viewport">
      <div ref="container" class="campus-canvas" />
      <div v-if="!loadedParts && status !== 'ready'" class="campus-fallback">
        <img v-if="!manifestUrl" src="/images/campus/teach1.png" alt="教一楼外观" width="1200" height="1000">
      </div>
      <div v-if="status !== 'ready'" class="campus-state" role="status">
        <UButton v-if="status === 'idle'" size="sm" color="neutral" variant="outline" @click="initialize">加载全校园</UButton>
        <span v-else>{{ status === 'loading' ? progress || '模型加载中' : loadedParts ? `已加载 ${loadedParts} 块，后续加载失败` : '模型暂时无法加载' }}</span>
        <UButton v-if="status === 'error'" size="sm" color="neutral" variant="outline" @click="initialize">重试</UButton>
      </div>
    </div>
  </div>
</template>

<style scoped>
.campus-scene { min-width: 0; background: var(--ui-bg); }
.campus-toolbar { display: flex; justify-content: flex-end; gap: .5rem; margin-bottom: .75rem; }
.campus-viewport { position: relative; height: 480px; overflow: hidden; border: 1px solid var(--ui-border); border-radius: .75rem; background: var(--ui-bg-muted); }
.campus-canvas { width: 100%; height: 100%; }
.campus-canvas :deep(canvas) { display: block; width: 100%; height: 100%; touch-action: none; }
.campus-canvas :deep(canvas:focus-visible) { outline: 2px solid var(--ui-primary); outline-offset: -3px; }
.campus-fallback { position: absolute; inset: 0; }
.campus-fallback img { width: 100%; height: 100%; object-fit: contain; }
.campus-state { position: absolute; left: 50%; bottom: 1rem; transform: translateX(-50%); display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .4rem .75rem; border-radius: .375rem; background: var(--ui-bg); color: var(--ui-text-muted); white-space: nowrap; }
.campus-scene:fullscreen { display: flex; flex-direction: column; padding: 1rem; }
.campus-scene:fullscreen .campus-viewport { flex: 1; height: auto; }
@media (max-width: 640px) { .campus-viewport { height: 360px; } }
</style>
