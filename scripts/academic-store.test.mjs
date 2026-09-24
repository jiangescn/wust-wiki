import test from 'node:test'
import assert from 'node:assert/strict'
import { createAcademicStore, ACADEMIC_TTL } from '../server/utils/academic-store.mjs'
import { parseSchoolGrades, readSchoolGrades } from '../server/utils/school-grades.mjs'

function harness() {
  let time = 1000, closes = 0, reads = 0
  let query = async resource => ({ state: 'complete', result: resource === 'grades' ? { courses: [] } : { lessons: [] } })
  const store = createAcademicStore({ now: () => time, adapterFactory: () => ({ close() { closes++ }, async start() { return { state: 'waiting', qr: 'test' } }, async poll() { return { state: 'authenticated' } }, async read(resource) { reads++; return query(resource) } }) })
  const origin = 'https://wiki.test'
  const call = (action, token, resource, from = origin) => store.handle({ body: { action, resource }, origin: from, authorization: token ? `Bearer ${token}` : '' })
  return { store, call, get closes() { return closes }, get reads() { return reads }, setTime(value) { time = value }, setQuery(fn) { query = fn }, async login() { const start = await call('start'); const token = start.data.sessionToken; const login = await call('poll', token); return { token, expiresAt: login.data.expiresAt } } }
}

test('same session reads grades and timetable, fixed expiry never renewed, logout revokes', async () => {
  const h = harness()
  try {
    const { token, expiresAt } = await h.login()
    assert.equal(expiresAt, 1000 + ACADEMIC_TTL)
    assert.equal(h.closes, 0)
    assert.equal((await h.call('query', token, 'grades')).status, 200)
    assert.equal((await h.call('query', token, 'schedule')).status, 200)
    h.setTime(5000)
    assert.equal((await h.call('inspect', token)).data.expiresAt, expiresAt)
    await h.call('logout', token)
    assert.equal(h.closes, 1)
    assert.equal((await h.call('query', token, 'grades')).status, 401)
  } finally { h.store.dispose() }
})

test('origin isolation, resource validation, school invalidation and exact 24 hour expiry', async () => {
  const h = harness()
  try {
    const { token, expiresAt } = await h.login()
    assert.equal((await h.call('query', token, 'grades', 'https://other.test')).status, 401)
    assert.equal((await h.call('query', token, 'arbitrary-url')).status, 400)
    h.setTime(expiresAt)
    assert.equal((await h.call('query', token, 'grades')).status, 401)
    const next = await h.login()
    h.setQuery(async () => ({ state: 'needs_action', message: 'expired' }))
    assert.equal((await h.call('query', next.token, 'grades')).status, 401)
    assert.equal((await h.call('inspect', next.token)).status, 401)
  } finally { h.store.dispose() }
})

test('cached queries avoid upstream repetition and late responses cannot revive logout', async () => {
  const h = harness()
  try {
    const { token } = await h.login()
    await h.call('query', token, 'grades'); await h.call('query', token, 'grades')
    assert.equal(h.reads, 1)
    let finish
    h.setQuery(() => new Promise(resolve => { finish = resolve }))
    const pending = h.call('query', token, 'schedule')
    assert.equal((await h.call('query', token, 'schedule')).status, 409)
    await h.call('logout', token)
    finish({ state: 'complete', result: { lessons: [] } })
    const result = await pending
    assert.equal(result.status, 401); assert.equal(result.data.result, undefined)
  } finally { h.store.dispose() }
})

test('unconfirmed QR expires independently of the one-day authenticated session', async () => {
  const h = harness()
  try { const start = await h.call('start'); h.setTime(start.data.expiresAt); assert.equal((await h.call('poll', start.data.sessionToken)).status, 401) }
  finally { h.store.dispose() }
})

test('grade parsing maps reordered headers, preserves nonnumeric grades and repeat attempts', () => {
  const html = '<table><tr><th>成绩</th><th>课程名称</th><th>学分</th><th>绩点</th><th>考试性质</th></tr><tr><td>优秀</td><td>示例体育</td><td>1</td><td>4.0</td><td>正常考试</td></tr><tr><td>缓考</td><td>示例体育</td><td>1</td><td></td><td>补考</td></tr></table>'
  const parsed = parseSchoolGrades(html)
  assert.equal(parsed.courses.length, 2)
  assert.equal(parsed.courses[0].score, '优秀')
  assert.equal(parsed.courses[1].score, '缓考')
  assert.equal(parsed.courses[1].point, '')
  assert.equal(parsed.courses[1].attempt, '补考')
  assert.equal(parseSchoolGrades('<html>登录</html>'), null)
  assert.equal(parseSchoolGrades('<table><tr><th>课程名称</th><th>成绩</th></tr><tr><td>错位</td></tr></table>'), null)
})

test('grade reader uses the observed endpoint and rejects login redirects', async () => {
  let requested
  const result = await readSchoolGrades({ request: async url => { requested = url; return { url: 'https://auth.wust.edu.cn/lyuapServer/login', bytes: Buffer.from('login') } } })
  assert.equal(requested, 'https://bkjx.wust.edu.cn/jsxsd/kscj/cjcx_list')
  assert.equal(result.state, 'needs_action')
})
