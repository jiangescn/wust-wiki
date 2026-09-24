<script setup lang="ts">
import type { AcademicView } from '~/types/academic'
const { snapshot, notice, save, clear } = useSchoolScheduleCache()
// Load the seven-day cache before the child decides whether a QR is needed.
const ready = ref(false)
onMounted(() => { ready.value = true })
const invalid = ref('')
function accept(data: AcademicView) { invalid.value = save(data.result) ? '' : '课表格式无法识别，请使用学校教务系统。' }
const dateText = (value: number) => new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false })
</script>
<template>
  <SchoolAcademicQuery v-if="ready" resource="schedule" :has-result="!!snapshot" @result="accept">
    <template #actions><UButton v-if="snapshot" color="neutral" variant="ghost" @click="clear">清除本机课表</UButton></template>
  </SchoolAcademicQuery>
  <p v-if="snapshot" class="sync-time">同步于 {{ dateText(snapshot.fetchedAt) }} · 有效至 {{ dateText(snapshot.expiresAt) }}</p>
  <p v-if="notice || invalid" role="status">{{ notice || invalid }}</p>
  <ScheduleBoard v-if="snapshot" :result="snapshot.result" />
</template>
<style scoped>.sync-time { font-size: .8rem; color: var(--ui-text-muted); }</style>
