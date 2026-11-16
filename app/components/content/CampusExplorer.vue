<script setup lang="ts">
const remoteModel = Boolean(useRuntimeConfig().public.campusManifestUrl)
</script>

<template>
  <section class="campus-explorer not-prose" aria-label="黄家湖校区三维预览">
    <ClientOnly>
      <CampusScene />
      <template #fallback>
        <div class="campus-placeholder">
          <img v-if="!remoteModel" src="/images/campus/teach1.png" alt="教一楼外观" width="1200" height="1000">
          <span role="status">{{ remoteModel ? '准备三维查看器' : '模型加载中' }}</span>
        </div>
      </template>
    </ClientOnly>
  </section>
</template>

<style scoped>
.campus-explorer { margin-bottom: 1.5rem; font: .875rem/1.5 var(--font-sans); color: var(--ui-text); }
.campus-placeholder { position: relative; display: grid; place-items: center; height: 480px; overflow: hidden; border: 1px solid var(--ui-border); border-radius: .75rem; background: var(--ui-bg-muted); color: var(--ui-text-muted); }
.campus-placeholder img { width: 100%; height: 100%; object-fit: contain; }
.campus-placeholder span { position: absolute; bottom: 1rem; padding: .4rem .75rem; border-radius: .375rem; background: var(--ui-bg); }
@media (max-width: 640px) { .campus-placeholder { height: 360px; } }
</style>
