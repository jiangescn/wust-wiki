import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import ts from 'typescript'

// Run the real component's request scheduler with a virtual clock and API.
// Vue rendering is covered separately in the browser; no school credentials here.
const source = readFileSync(new URL('../app/components/content/ScheduleQuery.vue', import.meta.url), 'utf8').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
const compiled = ts.transpileModule(source + '\nexpose({ start, cancel });', { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText
function harness({ pollLatency = 0, confirmedAt = 0, clearLatency = 0, apiBase = 'https://schedule.test' } = {}) {
  let time = 0, nextId = 0, component
  const jobs = new Map(), mounted = [], requests = []
  const snapshot = { value: null }
  const schedule = (fn, ms) => { const id = ++nextId; jobs.set(id, { at: time + ms, fn }); return id }
  runInNewContext(compiled, {
    exports: {}, require: () => ({ SCHEDULE_CACHE_KEY: 'test-cache' }),
    ref: value => ({ value }), computed: getter => ({ get value() { return getter() } }),
    useRuntimeConfig: () => ({ public: { scheduleApiBase: apiBase } }),
    useSchoolScheduleCache: () => ({ snapshot, notice: { value: '' }, save: value => { snapshot.value = value; return true }, clear: () => { snapshot.value = null }, expire() {} }),
    onMounted: fn => mounted.push(fn), onBeforeUnmount() {},
    window: { addEventListener() {}, removeEventListener() {} }, document: { hidden: false },
    Date: class extends Date { static now() { return time } }, performance: { now: () => time },
    setTimeout: schedule, clearTimeout: id => jobs.delete(id), setInterval: () => 0, clearInterval() {},
    AbortSignal: { timeout() {} },
    fetch: () => new Promise(resolve => schedule(resolve, clearLatency)),
    $fetch: async (_url, options) => {
      const action = options.body.action
      requests.push({ action, at: time })
      if (action === 'start') return { state: 'waiting', expiresAt: time + 180_000, sessionToken: 'test-only' }
      await new Promise(resolve => schedule(resolve, pollLatency))
      return time >= confirmedAt ? { state: 'complete', result: { provider: 'wust', lessons: [] } } : { state: 'waiting', expiresAt: 180_000 }
    },
    expose: value => { component = value },
  })
  const flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }
  const until = async end => {
    await flush()
    while (true) {
      const due = [...jobs].filter(([, job]) => job.at <= end).sort((a, b) => a[1].at - b[1].at)[0]
      if (!due) break
      time = due[1].at; jobs.delete(due[0]); due[1].fn(); await flush()
    }
    time = end
  }
  return { component, requests, snapshot, until, async mount() { mounted.forEach(fn => fn()); await flush() } }
}

test('already-confirmed QR is detected without a fixed multi-second first-poll delay', async () => {
  const h = harness({ pollLatency: 180 })
  await h.mount(); await h.until(1000)
  assert.ok(h.snapshot.value, `No timetable within 1 second: ${JSON.stringify(h.requests)}`)
})

test('slow polls do not add another full polling interval after every response', async () => {
  const h = harness({ pollLatency: 1200, confirmedAt: 20_000 })
  await h.mount(); await h.until(7000)
  const polls = h.requests.filter(r => r.action === 'poll').map(r => r.at)
  assert.ok(polls.length >= 3, `Polling starts: ${polls}`)
  for (let i = 1; i < polls.length; i++) assert.ok(polls[i] - polls[i - 1] >= 3000 && polls[i] - polls[i - 1] <= 3200)
})

test('new remote QR does not wait for cleanup of the previous independent session', async () => {
  const h = harness({ confirmedAt: 20_000, clearLatency: 10_000 })
  await h.mount(); h.component.cancel(); void h.component.start(); await h.until(1000)
  assert.equal(h.requests.filter(r => r.action === 'start').length, 2)
})

test('cancellation ignores an in-flight poll and prevents further polling', async () => {
  const h = harness({ pollLatency: 1000 })
  await h.mount(); await h.until(100); h.component.cancel(); await h.until(10_000)
  assert.equal(h.snapshot.value, null)
  assert.ok(h.requests.filter(r => r.action === 'poll').length <= 1)
})

test('local cookie-based restart still waits for old-session cleanup', async () => {
  const h = harness({ apiBase: '', confirmedAt: 20_000, clearLatency: 10_000 })
  await h.mount(); h.component.cancel(); void h.component.start(); await h.until(1000)
  assert.equal(h.requests.filter(r => r.action === 'start').length, 1)
  await h.until(10_000)
  assert.equal(h.requests.filter(r => r.action === 'start').length, 2)
})

test('polls slower than the cadence finish before another request begins', async () => {
  const h = harness({ pollLatency: 5000, confirmedAt: 30_000 })
  await h.mount(); await h.until(11_000)
  assert.deepEqual(h.requests.filter(r => r.action === 'poll').map(r => r.at), [0, 5000, 10_000])
})
