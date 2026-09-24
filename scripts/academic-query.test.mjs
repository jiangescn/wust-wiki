import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import ts from 'typescript'

const source = readFileSync(new URL('../app/components/content/SchoolAcademicQuery.vue', import.meta.url), 'utf8').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
const compiled = ts.transpileModule(source + '\nexpose({start, cancel, logout, onStorage});', { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText
function harness({ saved = null, hasResult = false, pollLatency = 180, confirmedAt = 0, queryLatency = 0 } = {}) {
  let time = 1000, nextId = 0, component, disk = saved && JSON.stringify(saved)
  const jobs = new Map(), mounted = [], unmounted = [], requests = [], events = [], releases = []
  const schedule = (fn, ms) => { const id = ++nextId; jobs.set(id, { at: time + ms, fn }); return id }
  runInNewContext(compiled, {
    exports: {}, require() {}, defineProps: () => ({ resource: 'grades', hasResult }), defineEmits: () => (...args) => events.push(args),
    ref: value => ({ value }), computed: getter => ({ get value() { return getter() } }),
    useRuntimeConfig: () => ({ public: { scheduleApiBase: '' } }),
    localStorage: { getItem: () => disk, setItem: (_, value) => { disk = value }, removeItem: () => { disk = null } },
    onMounted: fn => mounted.push(fn), onBeforeUnmount: fn => unmounted.push(fn),
    window: { addEventListener() {}, removeEventListener() {} }, document: { hidden: false },
    Date: class extends Date { static now() { return time } }, performance: { now: () => time },
    setTimeout: schedule, clearTimeout: id => jobs.delete(id), setInterval: () => 0, clearInterval() {}, AbortSignal: { timeout() {} },
    fetch: async (_url, options) => { releases.push(options.headers.Authorization) },
    $fetch: async (_url, options) => {
      const action = options.body.action; requests.push({ action, at: time })
      if (action === 'start') return { state: 'waiting', expiresAt: time + 180_000, sessionToken: 'a'.repeat(64) }
      if (action === 'inspect') return { state: 'authenticated', expiresAt: saved.expiresAt }
      if (action === 'query') { await new Promise(resolve => schedule(resolve, queryLatency)); return { state: 'complete', result: { courses: [] } } }
      await new Promise(resolve => schedule(resolve, pollLatency))
      return time >= confirmedAt ? { state: 'authenticated', expiresAt: time + 86_400_000 } : { state: 'waiting', expiresAt: 181_000 }
    }, expose: value => { component = value },
  })
  const flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve() }
  const until = async end => { await flush(); while (true) { const due = [...jobs].filter(([,job]) => job.at <= end).sort((a,b) => a[1].at - b[1].at)[0]; if (!due) break; time = due[1].at; jobs.delete(due[0]); due[1].fn(); await flush() }; time = end }
  return { component, requests, events, releases, until, get disk() { return disk && JSON.parse(disk) }, async mount() { mounted.forEach(fn => fn()); await flush() }, unmount() { unmounted.forEach(fn => fn()) } }
}

test('immediate QR poll queries grades and retains the authenticated session on navigation', async () => {
  const h = harness(); await h.mount(); await h.until(2000)
  assert.ok(h.events.some(([event]) => event === 'result'))
  assert.equal(h.disk.token, 'a'.repeat(64)); assert.equal(h.disk.expiresAt, 1180 + 86_400_000)
  h.unmount(); assert.equal(h.releases.length, 0)
})
test('restored login queries without a new QR and does not extend expiry', async () => {
  const h = harness({ saved: { token: 'a'.repeat(64), expiresAt: 50000 } }); await h.mount(); await h.until(2000)
  assert.deepEqual(h.requests.map(r => r.action), ['inspect', 'query'])
  assert.equal(h.disk.expiresAt, 50000)
})
test('valid cached timetable opens without network requests', async () => {
  const h = harness({ saved: { token: 'a'.repeat(64), expiresAt: 50000 }, hasResult: true }); await h.mount(); await h.until(2000)
  assert.equal(h.requests.length, 0)
})
test('logout prevents a late grade response from restoring results', async () => {
  const h = harness({ saved: { token: 'a'.repeat(64), expiresAt: 50000 }, queryLatency: 1000 }); await h.mount(); await h.until(1100)
  h.component.logout(); await h.until(3000)
  assert.equal(h.disk, null); assert.equal(h.events.filter(([event]) => event === 'result').length, 0)
  assert.equal(h.releases.length, 1)
})
test('poll cadence accounts for network latency without overlapping', async () => {
  const h = harness({ pollLatency: 1200, confirmedAt: 20000 }); await h.mount(); await h.until(8000)
  assert.deepEqual(h.requests.filter(r => r.action === 'poll').map(r => r.at), [1000, 4100, 7200])
})
