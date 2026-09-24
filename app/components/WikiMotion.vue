<script setup lang="ts">
// Animate layout without cloning or remounting slot content.
const props = withDefaults(defineProps<{ changeKey?: string | number; resize?: boolean; fadeFrom?: number }>(), { resize: true, fadeFrom: 0.5 })
const frame = ref<HTMLElement>()
const body = ref<HTMLElement>()
let observer: ResizeObserver | undefined
let preference: MediaQueryList | undefined
let heightAnimation: Animation | undefined
let fadeAnimation: Animation | undefined
let previousHeight = 0
const easing = 'cubic-bezier(.2,.7,.2,1)'
function stop() {
  heightAnimation?.cancel()
  fadeAnimation?.cancel()
  heightAnimation = fadeAnimation = undefined
}
function fade() {
  fadeAnimation?.cancel()
  if (!preference?.matches && body.value) {
    fadeAnimation = body.value.animate([{ opacity: props.fadeFrom }, { opacity: 1 }], { duration: 160, easing })
  }
}
watch(() => props.changeKey, fade, { flush: 'post' })
onMounted(() => {
  preference = window.matchMedia('(prefers-reduced-motion: reduce)')
  preference.addEventListener('change', stop)
  previousHeight = body.value!.getBoundingClientRect().height
  if (props.resize) {
    observer = new ResizeObserver(() => {
      if (!frame.value || !body.value) return
      const next = body.value.getBoundingClientRect().height
      const from = heightAnimation?.playState === 'running' ? frame.value.getBoundingClientRect().height : previousHeight
      previousHeight = next
      heightAnimation?.cancel()
      heightAnimation = undefined
      if (preference?.matches || Math.abs(next - from) < 1) return
      heightAnimation = frame.value.animate([
        { height: `${from}px`, overflow: 'clip' },
        { height: `${next}px`, overflow: 'clip' },
      ], { duration: 220, easing })
    })
    observer.observe(body.value!)
  }
})
onBeforeUnmount(() => { observer?.disconnect(); preference?.removeEventListener('change', stop); stop() })
</script>

<template>
  <div ref="frame" class="wiki-motion"><div ref="body" class="wiki-motion-body"><slot /></div></div>
</template>

<style scoped>
.wiki-motion { min-width: 0; max-width: 100%; }
.wiki-motion-body { display: flow-root; min-width: 0; }
</style>
