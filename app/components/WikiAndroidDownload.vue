<script setup lang="ts">
import Qrcode from '~/xupt/components/atomic/Qrcode.vue'

const downloadUrl = 'https://download.wust.club/wiki'
const open = ref(false)
let openedByHover = false
let closeTimer: ReturnType<typeof setTimeout> | undefined

function onPointerEnter(event: PointerEvent) {
  if (event.pointerType !== 'mouse') return
  clearTimeout(closeTimer)
  if (open.value) return

  openedByHover = true
  open.value = true
}

function onPointerLeave(event: PointerEvent) {
  if (event.pointerType !== 'mouse' || !openedByHover) return
  clearTimeout(closeTimer)
  closeTimer = setTimeout(() => {
    open.value = false
  }, 180)
}

function updateOpen(value: boolean) {
  clearTimeout(closeTimer)
  if (value) openedByHover = false
  open.value = value
}

function keepFocusOnHover(event: Event) {
  if (openedByHover) event.preventDefault()
}

onBeforeUnmount(() => clearTimeout(closeTimer))
</script>

<template>
  <UPopover
    :open="open"
    :content="{
      side: 'top',
      sideOffset: 8,
      collisionPadding: 16,
      onOpenAutoFocus: keepFocusOnHover,
      onCloseAutoFocus: keepFocusOnHover,
    }"
    :ui="{ content: 'rounded-xl' }"
    arrow
    @update:open="updateOpen"
  >
    <button
      type="button"
      class="wiki-entry cursor-pointer text-left"
      @pointerenter="onPointerEnter"
      @pointerleave="onPointerLeave"
    >
      <span class="wiki-entry-emoji" aria-hidden="true">📲</span>
      <span class="wiki-entry-title">安卓 App</span>
      <span class="wiki-entry-description">扫码或下载 APK</span>
    </button>

    <template #content>
      <div
        class="grid gap-2 p-4"
        @pointerenter="onPointerEnter"
        @pointerleave="onPointerLeave"
      >
        <Qrcode
          :src="downloadUrl"
          :uqr-options="{ border: 4, pixelSize: 1 }"
          size="9rem"
          text="用手机扫码"
          class="wiki-download-qr"
          role="img"
          aria-label="安卓 App 下载二维码"
        />
        <UButton :to="downloadUrl" external block icon="i-lucide-download">
          下载 APK
        </UButton>
      </div>
    </template>
  </UPopover>
</template>

<style scoped>
.wiki-download-qr :deep(svg) {
  display: block;
  width: 100%;
  height: auto;
  opacity: 1;
}
</style>
