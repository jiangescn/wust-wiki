<script setup lang="ts">
import type { AcademicView } from '~/types/academic'

const props = defineProps<{ resource: 'schedule' | 'grades'; hasResult?: boolean }>()
const emit = defineEmits<{ result: [data: AcademicView]; logout: [] }>()
const apiBase = useRuntimeConfig().public.scheduleApiBase.replace(/\/$/, '')
const apiUrl = apiBase + '/api/academic'
const storageKey = 'wust-wiki:academic-session:v1:' + (apiBase || 'local')
const view = ref<AcademicView>({ state: 'idle' })
const busy = ref(false), error = ref(''), notice = ref(''), now = ref(Date.now()), loggedIn = ref(false)
const pending = computed(() => ['waiting', 'scanned'].includes(view.value.state))
const remaining = computed(() => Math.max(0, Math.ceil(((view.value.expiresAt || 0) - now.value) / 1000)))
const label = computed(() => props.resource === 'grades' ? '成绩' : '课表')
let token = '', expiresAt = 0, generation = 0, leaving = false, autoRefresh = true
let pollTimer: ReturnType<typeof setTimeout> | undefined, ticker: ReturnType<typeof setInterval> | undefined
function stopTimer() { if (pollTimer) clearTimeout(pollTimer); pollTimer = undefined }
function forgetToken() { token = ''; expiresAt = 0; loggedIn.value = false; try { localStorage.removeItem(storageKey) } catch {} }
function persist() {
  try { localStorage.setItem(storageKey, JSON.stringify({ token, expiresAt })) }
  catch { notice.value = '浏览器未允许保存登录态，离开页面后需重新扫码。' }
}
function release(value: string) {
  if (value) void fetch(apiUrl, { method: 'POST', credentials: 'omit', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${value}` }, body: '{"action":"logout"}', keepalive: true, signal: AbortSignal.timeout(10_000) }).catch(() => {})
}
async function call(action: string, ticket: number): Promise<AcademicView | null> {
  const data = await $fetch<AcademicView>(apiUrl, { method: 'POST', credentials: 'omit', headers: token && action !== 'start' ? { Authorization: `Bearer ${token}` } : undefined, body: { action, ...(action === 'query' ? { resource: props.resource } : {}) }, timeout: 45_000, retry: 0 })
  if (leaving || ticket !== generation) { if (data.sessionToken) release(data.sessionToken); return null }
  if (data.sessionToken) token = data.sessionToken
  return data
}
function fail(cause: unknown) {
  autoRefresh = false
  const e = cause as { status?: number; statusCode?: number; data?: { message?: string } }
  if ((e.status || e.statusCode) === 401) { forgetToken(); emit('logout') }
  error.value = e.data?.message || '暂时无法连接教务查询服务，请稍后重试。'
  if (!loggedIn.value) { release(token); forgetToken() }
  view.value = { state: 'error' }; busy.value = false; stopTimer()
}
async function query(ticket = generation) {
  busy.value = true; error.value = ''
  try {
    const data = await call('query', ticket)
    if (!data) return
    view.value = data
    if (data.state === 'complete') emit('result', data)
    else error.value = data.message || '暂无法读取教务数据。'
  } catch (cause) { if (ticket === generation && !leaving) fail(cause) }
  finally { if (ticket === generation) busy.value = false }
}
async function accept(data: AcademicView, ticket: number) {
  now.value = Date.now()
  view.value = data
  if (data.state === 'authenticated') {
    loggedIn.value = true; expiresAt = data.expiresAt!; persist(); autoRefresh = false
    await query(ticket)
  } else if (!['waiting', 'scanned'].includes(data.state)) {
    autoRefresh = false; release(token); forgetToken(); error.value = data.message || '请重新扫码。'
  }
}
function poll(ticket: number, delay = 0) {
  stopTimer()
  if (!pending.value || leaving || ticket !== generation) return
  pollTimer = setTimeout(async () => {
    const started = performance.now()
    try { const data = await call('poll', ticket); if (data) { await accept(data, ticket); poll(ticket, Math.max(0, 3100 - (performance.now() - started))) } }
    catch (cause) { if (ticket === generation && !leaving) fail(cause) }
  }, delay)
}
async function start() {
  if (busy.value || pending.value) return
  if (loggedIn.value) { await query(); return }
  release(token); forgetToken(); autoRefresh = true; error.value = ''; busy.value = true
  const ticket = ++generation
  view.value = { state: 'creating' }
  try { const data = await call('start', ticket); if (data) { await accept(data, ticket); poll(ticket) } }
  catch (cause) { if (ticket === generation && !leaving) fail(cause) }
  finally { if (ticket === generation) busy.value = false }
}
function cancel() { ++generation; stopTimer(); autoRefresh = false; release(token); forgetToken(); busy.value = false; view.value = { state: 'idle' }; error.value = '' }
function logout() { cancel(); emit('logout') }
function onStorage(event: StorageEvent) {
  if (event.key !== storageKey && event.key !== null) return
  // Invalidates in-flight responses without deleting another tab's new session.
  ++generation; stopTimer(); if (!loggedIn.value) release(token)
  token = ''; expiresAt = 0; loggedIn.value = false; busy.value = false; view.value = { state: 'idle' }; emit('logout')
  void restore(false)
}
async function restore(create = true) {
  const restoreTicket = ++generation
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey) || 'null')
    if (saved && /^[a-f\d]{64}$/.test(saved.token) && Number.isFinite(saved.expiresAt) && Date.now() < saved.expiresAt && saved.expiresAt <= Date.now() + 86_400_000) { token = saved.token; expiresAt = saved.expiresAt }
    else if (saved) forgetToken()
  } catch { notice.value = '当前浏览器无法恢复登录态。' }
  if (token) {
    if (props.hasResult) { loggedIn.value = true; return }
    busy.value = true
    const ticket = restoreTicket
    try {
      const data = await call('inspect', ticket)
      if (!data) return
      if (data.state !== 'authenticated') { release(token); forgetToken() }
      else { loggedIn.value = true; expiresAt = data.expiresAt!; if (!props.hasResult) await query(ticket) }
    } catch (cause) { if (ticket === generation && !leaving) fail(cause) }
    finally { if (ticket === generation) busy.value = false }
  }
  if (create && restoreTicket === generation && !leaving && !loggedIn.value && !props.hasResult && !error.value) void start()
}
function onExit() { ++generation; stopTimer(); if (!loggedIn.value) { release(token); token = '' }; busy.value = false }
function onShow(event: PageTransitionEvent) { if (event.persisted) void restore() }
onMounted(() => {
  void restore()
  window.addEventListener('storage', onStorage); window.addEventListener('pagehide', onExit); window.addEventListener('pageshow', onShow)
  ticker = setInterval(() => {
    now.value = Date.now()
    if (loggedIn.value && now.value >= expiresAt) { logout(); error.value = '登录已到期，请重新扫码。' }
    if (pending.value && remaining.value === 0) { const refresh = autoRefresh; cancel(); autoRefresh = refresh; view.value = { state: 'expired' } }
    if (autoRefresh && view.value.state === 'expired' && !document.hidden) void start()
  }, 1000)
})
onBeforeUnmount(() => { leaving = true; onExit(); if (ticker) clearInterval(ticker); window.removeEventListener('storage', onStorage); window.removeEventListener('pagehide', onExit); window.removeEventListener('pageshow', onShow) })
</script>

<template>
  <section class="academic-query" :aria-label="`${label}查询`">
    <div class="query-toolbar">
      <UButton :loading="busy" :disabled="busy || pending" @click="start">{{ loggedIn ? `刷新${label}` : `微信扫码查${label}` }}</UButton>
      <UButton v-if="pending || (busy && !loggedIn)" color="neutral" variant="outline" @click="cancel">取消扫码</UButton>
      <UButton v-if="loggedIn" color="neutral" variant="ghost" @click="logout">退出登录</UButton>
      <slot name="actions" />
      <a href="https://bkjx.wust.edu.cn/jsxsd/framework/xsMain.jsp" target="_blank" rel="noopener noreferrer">学校教务系统 ↗</a>
    </div>
    <p v-if="loggedIn" class="session-note">登录保留至 {{ new Date(expiresAt).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }) }}</p>
    <p v-if="notice" role="status">{{ notice }}</p>
    <p v-if="error" role="alert" class="query-error">{{ error }}</p>
    <div v-if="pending || view.state === 'creating'" class="scan-panel">
      <img v-if="view.qr && pending" :src="view.qr" alt="学校微信登录二维码" width="240" height="240" referrerpolicy="no-referrer">
      <p>{{ pending ? `微信扫码 · ${remaining} 秒` : '正在生成二维码…' }}</p>
    </div>
  </section>
</template>

<style scoped>
.academic-query { margin: 1rem 0; min-width: 0; }
.query-toolbar { display: flex; align-items: center; flex-wrap: wrap; gap: .65rem; }
.query-toolbar a { font-size: .8rem; color: var(--ui-primary); margin-left: auto; }
.session-note { color: var(--ui-text-muted); font-size: .8rem; }
.query-error { color: var(--ui-error); }
.scan-panel { display: flex; flex-direction: column; align-items: center; padding: 1rem; border: 1px solid var(--ui-border); border-radius: 12px; margin-top: 1rem; }
.scan-panel img { width: 264px; max-width: 100%; height: auto; background: white; border: 12px solid white; image-rendering: pixelated; }
.scan-panel p { margin: 0; font-size: .8rem; }
</style>
