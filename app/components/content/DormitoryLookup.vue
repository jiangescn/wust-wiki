<script setup lang="ts">
type ResultData = {
  area: string
  room: string
  type: 'standard_5' | 'standard_4' | 'special_5' | 'special_4' | 'special_3' | 'unknown'
  people: number | null
}

type BridgeMessage = {
  source?: unknown
  type?: unknown
  requestId?: unknown
  status?: unknown
  code?: unknown
  data?: unknown
}

const config = useRuntimeConfig()
const embedUrl = String(config.public.dormitoryEmbedUrl)
const embedOrigin = new URL(embedUrl).origin
const iframe = ref<HTMLIFrameElement>()
const area = ref('')
const room = ref('')
const ready = ref(false)
const isWorking = ref(false)
const status = ref('正在加载查询组件…')
const result = ref<ResultData | null>(null)
const activeRequestId = ref<string | null>(null)

const typeLabels: Record<ResultData['type'], string> = {
  standard_5: '标准五人寝', standard_4: '标准四人寝', special_5: '特殊五人寝',
  special_4: '特殊四人寝', special_3: '特殊三人寝', unknown: '暂未确认',
}

const errorMessages: Record<string, string> = {
  ROOM_UNAVAILABLE: '当前无法查询该寝室信息，请确认区域和寝室号。',
  SERVICE_UNAVAILABLE: '查询服务暂时不可用，请稍后再试。',
  HUMAN_VERIFICATION_REQUIRED: '请重新完成人机验证后再查询。',
  VERIFICATION_UNAVAILABLE: '验证服务暂时不可用，请稍后再试。',
  INVALID_REQUEST: '请输入正确的区域和完整寝室号。',
}

function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null }
function isResultData(value: unknown): value is ResultData {
  if (!isRecord(value) || typeof value.area !== 'string' || typeof value.room !== 'string') return false
  if (typeof value.type !== 'string' || !Object.hasOwn(typeLabels, value.type) || (value.people !== null && !Number.isInteger(value.people))) return false
  return value.type !== 'unknown' || value.people === null
}
function makeRequestId() {
  return typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID().replaceAll('-', '')
    : `${Date.now()}${Math.random().toString(36).slice(2)}`
}

function handleMessage(event: MessageEvent<unknown>) {
  if (event.origin !== embedOrigin || event.source !== iframe.value?.contentWindow || !isRecord(event.data)) return
  const message = event.data as BridgeMessage
  if (message.source !== 'qinhudorm' || typeof message.type !== 'string') return
  if (message.type === 'QINHUDORM_EMBED_READY') {
    ready.value = true
    if (!isWorking.value) status.value = '请输入区域和完整寝室号。'
    return
  }
  if (message.type === 'QINHUDORM_EMBED_UNAVAILABLE') {
    ready.value = false; isWorking.value = false; status.value = '查询验证组件暂时不可用，请稍后再试。'
    return
  }
  if (message.requestId !== activeRequestId.value) return
  if (message.type === 'QINHUDORM_EMBED_STATUS') {
    if (message.status === 'verification-retry') status.value = '验证未通过，请在下方验证码中重新完成验证。'
    else if (message.status === 'verifying') status.value = '请在下方完成人机验证。'
    else if (message.status === 'querying') status.value = '验证成功，正在查询…'
    return
  }
  isWorking.value = false
  if (message.type === 'QINHUDORM_EMBED_RESULT' && isResultData(message.data)) {
    result.value = message.data; status.value = '查询完成。'; return
  }
  if (message.type === 'QINHUDORM_EMBED_ERROR' && typeof message.code === 'string') {
    status.value = errorMessages[message.code] || '查询暂时不可用，请稍后再试。'
  }
}

function submit() {
  const normalizedArea = area.value.trim().toUpperCase()
  const normalizedRoom = room.value.trim()
  if (!['A', 'B', 'C', 'D'].includes(normalizedArea) || !/^[0-9]{3,16}$/.test(normalizedRoom)) {
    status.value = '请输入正确的区域和完整寝室号。'; return
  }
  if (!ready.value || !iframe.value?.contentWindow) {
    status.value = '验证组件仍在加载，请稍后再试。'; return
  }
  const requestId = makeRequestId()
  activeRequestId.value = requestId; result.value = null; isWorking.value = true; status.value = '请在下方完成人机验证。'
  iframe.value.contentWindow.postMessage({ source: 'wust-wiki', type: 'QINHUDORM_EMBED_QUERY', requestId, area: normalizedArea, room: normalizedRoom }, embedOrigin)
}

onMounted(() => window.addEventListener('message', handleMessage))
onBeforeUnmount(() => window.removeEventListener('message', handleMessage))
</script>

<template>
  <section class="dormitory-lookup not-prose" aria-labelledby="dormitory-lookup-title">
    <h2 id="dormitory-lookup-title">沁湖宿舍类型查询</h2>
    <p class="dormitory-lookup-intro">选择区域并输入完整寝室号；每次查询都需要完成一次人机验证。</p>
    <form class="dormitory-lookup-form" @submit.prevent="submit">
      <label><span>区域</span><select v-model="area" :disabled="isWorking"><option value="">请选择区域</option><option value="A">A 区</option><option value="B">B 区</option><option value="C">C 区</option><option value="D">D 区</option></select></label>
      <label><span>寝室号</span><input v-model="room" type="text" inputmode="numeric" autocomplete="off" maxlength="16" placeholder="例如：1308" :disabled="isWorking"></label>
      <button type="submit" :disabled="isWorking || !ready">{{ isWorking ? '验证或查询中…' : '查询寝室' }}</button>
    </form>
    <p class="dormitory-lookup-status" aria-live="polite">{{ status }}</p>
    <iframe ref="iframe" class="dormitory-lookup-frame" :class="{ 'dormitory-lookup-frame-active': isWorking }" :src="embedUrl" title="沁湖宿舍查询人机验证" />
    <div v-if="result" class="dormitory-lookup-result" aria-live="polite"><p>{{ result.area }} 区 · {{ result.room }}</p><strong>{{ typeLabels[result.type] }}</strong><span v-if="result.people !== null">{{ result.people }} 人</span><span v-else>该寝室暂无可靠的类型信息</span></div>
  </section>
</template>

<style scoped>
.dormitory-lookup { margin: 1.5rem 0; padding: 1.25rem; border: 1px solid var(--ui-border); border-radius: .75rem; background: var(--ui-bg); }
.dormitory-lookup h2 { margin: 0; font-size: 1.15rem; }.dormitory-lookup-intro, .dormitory-lookup-status { margin: .55rem 0 0; color: var(--ui-text-muted); font-size: .92rem; line-height: 1.6; }
.dormitory-lookup-form { display: grid; grid-template-columns: 8rem minmax(0, 1fr) auto; gap: .75rem; align-items: end; margin-top: 1rem; }.dormitory-lookup-form label { display: grid; gap: .35rem; color: var(--ui-text); font-size: .88rem; font-weight: 600; }
.dormitory-lookup-form select, .dormitory-lookup-form input, .dormitory-lookup-form button { min-height: 2.6rem; border-radius: .45rem; font: inherit; }.dormitory-lookup-form select, .dormitory-lookup-form input { width: 100%; border: 1px solid var(--ui-border); padding: .5rem .65rem; background: var(--ui-bg); color: var(--ui-text); }.dormitory-lookup-form button { border: 0; padding: .5rem 1rem; background: var(--ui-primary); color: var(--ui-bg); font-weight: 700; cursor: pointer; }.dormitory-lookup-form button:disabled { cursor: wait; opacity: .65; }
.dormitory-lookup-frame { display: block; width: 100%; height: 2px; margin-top: .5rem; border: 0; transition: height 160ms ease; }.dormitory-lookup-frame-active { height: 28rem; border: 1px solid var(--ui-border); border-radius: .45rem; }.dormitory-lookup-result { display: grid; gap: .35rem; margin-top: 1rem; padding: 1rem; border-radius: .5rem; background: color-mix(in srgb, var(--ui-primary) 10%, var(--ui-bg)); }.dormitory-lookup-result p { margin: 0; color: var(--ui-text-muted); font-size: .9rem; }.dormitory-lookup-result strong { font-size: 1.2rem; }.dormitory-lookup-result span { color: var(--ui-text-muted); }
@media (max-width: 639px) { .dormitory-lookup-form { grid-template-columns: 1fr; }.dormitory-lookup-form button { width: 100%; } } @media (prefers-reduced-motion: reduce) { .dormitory-lookup-frame { transition: none; } }
</style>
