<script setup lang="ts">
const route = useRoute()
const sample = computed(() => route.query.schedule === 'sample')
const apiBase = useRuntimeConfig().public.scheduleApiBase
// Warm DNS/TLS while the static page loads, before the client-only login mounts.
useHead(() => ({ link: !sample.value && apiBase.startsWith('https://')
  ? [{ rel: 'preconnect', href: new URL(apiBase).origin, crossorigin: 'anonymous' }]
  : [] }))
</script>

<template>
  <ClientOnly>
  <div>
    <template v-if="sample">
      <div class="sample-heading"><UBadge color="neutral" variant="subtle">交互样例</UBadge><NuxtLink to="/study/curriculum">返回扫码查询 →</NuxtLink></div>
      <ScheduleGridPrototype />
    </template>
    <template v-else>
      <AcademicSchedule />
    </template>
  </div>
  <template #fallback><p>正在加载课表…</p></template>
  </ClientOnly>
</template>

<style scoped>
.sample-heading { display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
</style>
