<script setup lang="ts">
import type { LoginProvider, LoginView } from '~~/server/utils/login-template-store.mjs'

const props = withDefaults(defineProps<{ experimental?: boolean }>(), { experimental: false })
const apiBase = useRuntimeConfig().public.scheduleApiBase.replace(/\/$/, '')
const apiUrl = apiBase + '/api/login-template'
type Provider = { id: LoginProvider; title: string; scanner: string; description: string; boundary: string; officialUrl: string }
const providers = ref<Provider[]>([])
const selected = ref<LoginProvider>(props.experimental ? 'chaoxing' : 'wust')
const view = ref<LoginView>({ state: 'idle', message: '点击生成二维码开始查询。' })
const enabled = ref(false)
const deployment = ref(Boolean(apiBase))
const busy = ref(false)
const error = ref('')
const clock = ref(Date.now())
let timer: ReturnType<typeof setTimeout> | undefined
let ticker: ReturnType<typeof setInterval> | undefined
let epoch = 0
let leaving = false
let remoteSession = ''
const provider = computed(() => providers.value.find(p => p.id === selected.value))
const pending = computed(() => ['waiting', 'scanned'].includes(view.value.state))
const remaining = computed(() => Math.max(0, Math.ceil(((view.value.expiresAt || 0) - clock.value) / 1000)))
const labels: Record<string, string> = { idle: '未开始', waiting: '等待扫码', scanned: '等待确认', complete: '已获取课表', needs_action: '需要在官网继续', needs_adapter: '教务课表待适配', error: '连接失败', expired: '已过期', cancelled: '已取消', throttled: '请稍后', creating: '正在创建' }

async function call(action: string, extra: Record<string, string> = {}) {
  const generation = epoch
  try {
    const data = await $fetch<LoginView & { providers?: Provider[]; deployment?: boolean; sessionToken?: string }>(apiUrl, { method: 'POST', credentials: apiBase ? 'omit' : 'same-origin', headers: remoteSession ? { Authorization: `Bearer ${remoteSession}` } : undefined, body: { action, ...extra } })
    if (generation === epoch) {
      if (data.sessionToken) remoteSession = data.sessionToken
      if (action === 'clear') remoteSession = ''
    }
    return data
  } catch (cause) {
    if (generation === epoch && (cause as { status?: number }).status === 401) remoteSession = ''
    throw cause
  }
}
function cancelTimer() { if (timer) clearTimeout(timer); timer = undefined }
function schedulePoll() {
  cancelTimer()
  if (!pending.value || leaving) return
  const ticket = epoch
  timer = setTimeout(async () => {
    try {
      const result = await call('poll')
      if (ticket !== epoch || leaving) return
      view.value = result
      schedulePoll()
    } catch {
      if (ticket !== epoch || leaving) return
      error.value = '无法连接课表服务。轮询已停止，正在清除临时会话。'
      view.value = { state: 'error', message: '连接中断，请重新开始。' }
      void call('clear').catch(() => {})
    }
  }, 3500)
}
async function clear() {
  ++epoch; cancelTimer(); busy.value = true; error.value = ''
  view.value = { state: 'idle', message: '临时会话与当前结果已清除。' }
  try { await call('clear') } catch { error.value = '未能联系课表服务；服务端会按到期时间自动清除。' }
  finally { busy.value = false }
}
async function choose(id: LoginProvider) {
  if (busy.value || id === selected.value) return
  await clear(); selected.value = id
}
async function start() {
  if (busy.value) return
  ++epoch; cancelTimer(); busy.value = true; error.value = ''
  const ticket = epoch
  view.value = { state: 'creating', message: '正在获取二维码。' }
  try {
    const result = await call('start', { provider: selected.value })
    if (ticket !== epoch || leaving) return
    clock.value = Date.now(); view.value = result; schedulePoll()
  } catch { if (ticket === epoch && !leaving) view.value = { state: 'error', message: !props.experimental || deployment.value ? '课表服务暂时不可用，请稍后重试。' : '本地服务不可用，请确认已通过 pnpm dev:login 启动。' } }
  finally { busy.value = false }
}
function forgetOnExit() {
  ++epoch; cancelTimer()
  view.value = { state: 'idle', message: '已离开查询页面，当前数据已清除。' }
  void fetch(apiUrl, { method: 'POST', credentials: apiBase ? 'omit' : 'same-origin', headers: { 'Content-Type': 'application/json', ...(remoteSession ? { Authorization: `Bearer ${remoteSession}` } : {}) }, body: '{"action":"clear"}', keepalive: true }).catch(() => {})
  remoteSession = ''
}
onMounted(async () => {
  window.addEventListener('pagehide', forgetOnExit)
  ticker = setInterval(() => { clock.value = Date.now() }, 1000)
  try {
    const data = await call('inspect')
    if (leaving) return
    providers.value = (data.providers || []).filter(p => props.experimental || p.id === 'wust')
    enabled.value = true; deployment.value = data.deployment === true
    if (!props.experimental && data.provider && data.provider !== 'wust') {
      await clear()
    } else {
      view.value = data
    }
    selected.value = props.experimental ? data.provider || providers.value[0]?.id || 'wust' : 'wust'
    schedulePoll()
  } catch { error.value = !props.experimental || deployment.value ? '课表服务暂时不可用，请稍后刷新页面，或前往学校教务系统查询。' : '请运行 pnpm dev:login（本机）或 pnpm dev:login:lan（局域网），并打开终端显示的地址。' }
})
onBeforeUnmount(() => { leaving = true; forgetOnExit(); if (ticker) clearInterval(ticker); window.removeEventListener('pagehide', forgetOnExit) })
</script>

<template>
  <div class="schedule-query" aria-label="课表查询">
    <p class="intro">{{ !experimental || deployment ? '使用学校绑定的微信扫码，读取当前学期课表，无需输入账号密码。' : '选择扫码方式，验证登录与课表读取流程。模板供本机与局域网测试，不要求输入账号密码。' }}</p>
    <p class="privacy">登录会话仅保存在服务端内存中，完成、取消或到期后清除；服务端结果临时保留五分钟。离开本页或点击“取消并清除”会清除当前显示的结果。</p>
    <p v-if="error" role="alert" class="error">{{ error }}</p>
    <p v-if="!enabled && !error" role="status">正在连接课表服务…</p>
    <div v-if="enabled && experimental" class="providers" aria-label="登录方式">
      <button v-for="p in providers" :key="p.id" type="button" :aria-pressed="selected === p.id" :disabled="busy" @click="choose(p.id)">
        <strong>{{ p.title }}</strong><span>{{ p.description }}</span>
      </button>
    </div>
    <UCard v-if="enabled && provider" class="session">
      <template #header><div class="session-heading"><h3>{{ provider.title }}</h3><UBadge color="neutral" variant="subtle">{{ labels[view.state] || view.state }}</UBadge></div></template>
      <p v-if="experimental">{{ provider.boundary }}</p>
      <div class="actions">
        <UButton :loading="busy" :disabled="busy" @click="start">{{ pending ? '重新生成二维码' : '生成登录二维码' }}</UButton>
        <UButton color="neutral" variant="outline" :disabled="busy" @click="clear">取消并清除</UButton>
        <a :href="provider.officialUrl" target="_blank" rel="noopener noreferrer">前往官方教务 / 登录入口 ↗</a>
      </div>
      <div v-if="view.qr && pending" class="qr-box">
        <img :src="view.qr" :alt="provider.title + '二维码'" width="240" height="240" referrerpolicy="no-referrer">
        <p>使用{{ provider.scanner }}扫描 · 剩余 {{ remaining }} 秒</p>
      </div>
      <p role="status" aria-live="polite">{{ view.message }}</p>
      <p v-if="view.state === 'needs_adapter'">暂时无法读取课表，请通过上方官方入口查询。</p>
      <section v-if="view.result" class="result">
        <h3>本次读取结果</h3>
        <p v-if="view.result.curriculumUuid" class="uuid">课表 UUID：<code>{{ view.result.curriculumUuid }}</code></p>
        <p v-if="view.result.schoolYear">{{ view.result.schoolYear }} 学年 · 第 {{ view.result.semester }} 学期<span v-if="view.result.currentWeek"> · 第 {{ view.result.currentWeek }} 周</span><span v-else-if="view.result.provider === 'wust'"> · 全学期</span></p>
        <p>{{ view.result.lessons.length }} 条排课。结果只保留在当前临时会话中；请以学校教务系统为准。</p>
        <div class="table-scroll">
          <table><thead><tr><th>课程</th><th>教师</th><th>地点</th><th>星期 / 节次</th><th>周次</th></tr></thead>
            <tbody><tr v-for="(lesson, index) in view.result.lessons" :key="index"><td>{{ lesson.name || '未提供' }}<span v-if="lesson.group"> {{ lesson.group }}</span></td><td>{{ lesson.teacher || '未提供' }}</td><td>{{ lesson.location || '未提供' }}</td><td>{{ lesson.day ?? '—' }} / <template v-if="lesson.sections">{{ lesson.sections }}</template><template v-else>{{ lesson.start ?? '—' }}<span v-if="lesson.end">–{{ lesson.end }}</span><span v-else-if="lesson.length"> 起 {{ lesson.length }} 节</span></template></td><td>{{ lesson.weeks || '未提供' }}</td></tr></tbody>
          </table>
        </div>
        <template v-if="view.result.notes?.length">
          <h3>教务课表备注</h3>
          <p>以下条目未列入上方的星期与节次排课，保留学校原备注。</p>
          <ul><li v-for="(note, index) in view.result.notes" :key="index">{{ note }}</li></ul>
        </template>
      </section>
    </UCard>
    <a v-if="error && !enabled" href="https://bkjx.wust.edu.cn/jsxsd/framework/xsMain.jsp" target="_blank" rel="noopener noreferrer">前往学校教务系统 ↗</a>
  </div>
</template>

<style scoped>
.schedule-query { min-width: 0; max-width: 100%; margin: 1rem 0 2rem; }
h2, h3 { font-weight: 600; }
p { margin: .8rem 0; }
.intro { color: var(--ui-text-muted); margin-bottom: 1.5rem; }
.privacy { color: var(--ui-text-muted); font-size: .875rem; }
.session { min-width: 0; }
.session-heading h3 { margin: 0; }
.providers { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin: 1.5rem 0; }
.providers button { text-align: left; border: 1px solid var(--ui-border); border-radius: .75rem; padding: 1rem; cursor: pointer; }
.providers button[aria-pressed="true"] { border-color: var(--ui-primary); background: var(--ui-bg-elevated); }
.providers button:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 3px; }
.providers span { display: block; color: var(--ui-text-muted); font-size: .875rem; margin-top: .5rem; }
.session-heading, .actions { display: flex; gap: 1rem; align-items: center; flex-wrap: wrap; }
.session-heading { justify-content: space-between; }
.actions { margin: 1rem 0; }
a { color: var(--ui-primary); text-decoration: underline; text-underline-offset: 3px; }
.qr-box { text-align: center; margin: 1.5rem auto; }
.qr-box img { margin: auto; background: white; border: 12px solid white; width: 264px; max-width: 100%; height: auto; image-rendering: pixelated; }
.error { color: var(--ui-error); }
.uuid { overflow-wrap: anywhere; }
.result { margin-top: 2rem; }
.table-scroll { overflow-x: auto; max-width: 100%; }
table { width: 100%; border-collapse: collapse; font-size: .875rem; }
th, td { text-align: left; padding: .7rem; border-bottom: 1px solid var(--ui-border); min-width: 5rem; }
@media (max-width: 640px) { .providers { grid-template-columns: 1fr; } }
</style>
