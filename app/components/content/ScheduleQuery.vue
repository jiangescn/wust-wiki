<script setup lang="ts">
import type { LoginView } from '~~/server/utils/login-template-store.mjs'
import { SCHEDULE_CACHE_KEY } from '~/utils/schedule'

const apiBase = useRuntimeConfig().public.scheduleApiBase.replace(/\/$/, '')
const apiUrl = apiBase + '/api/login-template'
const { snapshot, notice, save, clear: clearCache, expire } = useSchoolScheduleCache()
const view = ref<LoginView>({ state: 'idle', message: '' })
const busy = ref(false)
const error = ref('')
const clock = ref(Date.now())
const pending = computed(() => ['waiting', 'scanned'].includes(view.value.state))
const active = computed(() => busy.value || pending.value)
const remaining = computed(() => Math.max(0, Math.ceil(((view.value.expiresAt || 0) - clock.value) / 1000)))
const statusMessage = computed(() => ['error', 'expired', 'needs_action', 'needs_adapter', 'throttled'].includes(view.value.state) ? view.value.message : '')
const labels: Record<string, string> = { idle: '微信扫码', creating: '正在生成', waiting: '等待扫码', scanned: '等待确认', complete: '同步完成', needs_action: '请前往官网', needs_adapter: '暂无法读取', error: '连接失败', expired: '二维码过期', throttled: '请稍后' }
let pollTimer: ReturnType<typeof setTimeout> | undefined
let ticker: ReturnType<typeof setInterval> | undefined
let generation = 0
let sessionToken = ''
let usedSession = false
let leaving = false
let autoRefresh = false
let cleanup: Promise<unknown> = Promise.resolve()
const dateText = (value: number) => new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false })
function cancelTimer() { if (pollTimer) clearTimeout(pollTimer); pollTimer = undefined }
function release(token = sessionToken) {
  if (!usedSession && !token) return
  cleanup = fetch(apiUrl, { method: 'POST', credentials: apiBase ? 'omit' : 'same-origin', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: '{"action":"clear"}', keepalive: true, signal: AbortSignal.timeout(10_000) }).catch(() => {})
}
async function call(action: 'start' | 'poll', ticket: number) {
  usedSession = true
  const data = await $fetch<LoginView & { sessionToken?: string }>(apiUrl, { method: 'POST', credentials: apiBase ? 'omit' : 'same-origin', headers: sessionToken ? { Authorization: `Bearer ${sessionToken}` } : undefined, body: { action, ...(action === 'start' ? { provider: 'wust' } : {}) }, timeout: 25_000, retry: 0 })
  if (ticket !== generation || leaving) { if (data.sessionToken) release(data.sessionToken); return null }
  if (data.sessionToken) sessionToken = data.sessionToken
  return data
}
function accept(data: LoginView) {
  view.value = data
  if (data.state === 'complete') {
    autoRefresh = false
    if (!save(data.result)) { view.value = { state: 'error', message: '返回的课表格式不完整，请前往学校教务系统查询。' } }
    release(); sessionToken = ''; usedSession = false
  }
}
function fail(cause: unknown) {
  autoRefresh = false
  const status = (cause as { status?: number }).status
  error.value = status === 429 ? '请求较多，请一分钟后重试。' : status === 401 ? '扫码会话已到期，请重新生成二维码。' : '暂时无法连接课表服务，请稍后重试或前往学校教务系统。'
  view.value = { state: 'error', message: snapshot.value ? '本次未更新，仍显示上次保存的课表。' : '' }
  release(); sessionToken = ''; usedSession = false
}
function poll(ticket: number, delay = 0) {
  cancelTimer()
  if (!pending.value || leaving || ticket !== generation) return
  pollTimer = setTimeout(async () => {
    const startedAt = performance.now()
    try {
      const data = await call('poll', ticket)
      if (!data) return
      accept(data)
      // Keep the server's 3-second minimum without adding network time each cycle.
      poll(ticket, Math.max(0, 3100 - (performance.now() - startedAt)))
    }
    catch (cause) { if (ticket === generation && !leaving) fail(cause) }
  }, delay)
}
async function start() {
  if (active.value) return
  autoRefresh = true
  expire(); error.value = ''; busy.value = true
  const ticket = ++generation
  view.value = { state: 'creating', message: '正在获取学校微信二维码…' }
  try {
    // Remote starts use a fresh bearer session; only the local cookie flow shares an owner.
    if (!apiBase) await cleanup
    if (ticket !== generation || leaving) return
    const data = await call('start', ticket)
    if (data) { accept(data); poll(ticket) }
  }
  catch (cause) { if (ticket === generation && !leaving) fail(cause) }
  finally { if (ticket === generation) busy.value = false }
}
function cancel() {
  autoRefresh = false
  ++generation; cancelTimer(); release(); sessionToken = ''; usedSession = false; busy.value = false; error.value = ''
  view.value = { state: 'idle', message: snapshot.value ? '已取消同步，保留上次课表。' : '已取消扫码。' }
}
function forget() { cancel(); clearCache(); void start() }
function onExit() { autoRefresh = false; ++generation; cancelTimer(); release(); sessionToken = ''; usedSession = false; busy.value = false; view.value = { state: 'idle', message: '' } }
function onPageShow(event: PageTransitionEvent) { if (event.persisted && !snapshot.value && !active.value) void start() }
function onStorage(event: StorageEvent) { if ((event.key === SCHEDULE_CACHE_KEY || event.key === null) && event.newValue === null) cancel() }
onMounted(() => {
  window.addEventListener('pagehide', onExit)
  window.addEventListener('pageshow', onPageShow)
  window.addEventListener('storage', onStorage)
  if (!snapshot.value) void start()
  ticker = setInterval(() => {
    clock.value = Date.now()
    if (pending.value && remaining.value === 0) {
      const refresh = autoRefresh
      cancel(); autoRefresh = refresh
      view.value = { state: 'expired', message: '二维码已过期，请重新生成。' }
    }
    if (autoRefresh && view.value.state === 'expired' && !document.hidden && !busy.value) {
      cancel()
      void start()
    }
  }, 1000)
})
onBeforeUnmount(() => { leaving = true; onExit(); if (ticker) clearInterval(ticker); window.removeEventListener('pagehide', onExit); window.removeEventListener('pageshow', onPageShow); window.removeEventListener('storage', onStorage) })
</script>

<template>
  <div class="school-schedule">
    <div class="query-toolbar">
      <UButton :loading="busy" :disabled="active" @click="start">{{ snapshot ? '重新扫码更新' : '微信扫码查课表' }}</UButton>
      <UButton v-if="active" color="neutral" variant="outline" @click="cancel">取消扫码</UButton>
      <UButton v-if="snapshot" color="neutral" variant="ghost" @click="forget">清除本机课表</UButton>
      <a href="https://bkjx.wust.edu.cn/jsxsd/framework/xsMain.jsp" target="_blank" rel="noopener noreferrer">学校教务系统 ↗</a>
    </div>
    <p v-if="snapshot" class="cache-status">同步于 {{ dateText(snapshot.fetchedAt) }} · 有效至 {{ dateText(snapshot.expiresAt) }}</p>
    <p v-if="notice" role="status" class="cache-notice">{{ notice }}</p>
    <p v-if="error" role="alert" class="query-error">{{ error }}</p>
    <div v-if="active" class="scan-panel">
      <UBadge color="neutral" variant="subtle">{{ labels[view.state] || view.state }}</UBadge>
      <img v-if="view.qr && pending" :src="view.qr" alt="学校微信登录二维码" width="240" height="240" referrerpolicy="no-referrer">
      <p v-if="pending">微信扫码 · {{ remaining }} 秒</p>
    </div>
    <p v-if="statusMessage" role="status" aria-live="polite">{{ statusMessage }}</p>
    <ScheduleBoard v-if="snapshot" :result="snapshot.result" />
  </div>
</template>

<style scoped>
.school-schedule { min-width: 0; max-width: 100%; margin: 1rem 0 2rem; }
.query-toolbar { display: flex; align-items: center; flex-wrap: wrap; gap: .65rem; }
.query-toolbar a { font-size: .8rem; color: var(--ui-primary); margin-left: auto; }
.cache-status { font-size: .85rem; margin: .9rem 0 .4rem; }
.query-error { color: var(--ui-error); }
.cache-notice { font-size: .8rem; color: var(--ui-text-muted); }
.scan-panel { display: flex; flex-direction: column; align-items: center; gap: .75rem; padding: 1rem; border: 1px solid var(--ui-border); border-radius: 12px; margin-top: 1rem; }
.scan-panel img { width: 264px; max-width: 100%; height: auto; background: white; border: 12px solid white; image-rendering: pixelated; }
.scan-panel p { margin: 0; font-size: .8rem; }
</style>
