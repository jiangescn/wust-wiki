import test from 'node:test'
import assert from 'node:assert/strict'
import { createLoginAdapter } from '../server/utils/login-template-adapters.mjs'
import { createLoginStore, isLocalLoginRequest } from '../server/utils/login-template-store.mjs'
import { createUpstreamClient } from '../server/utils/login-template-http.mjs'

const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
const qr = 'data:image/png;base64,' + png.toString('base64')
const json = (data, headers) => new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json', ...headers } })
const id = '12345678-1234-1234-1234-123456789abc'

test('login routes require opt-in, direct loopback and matching Origin', () => {
  const good = { enabled: true, host: '127.0.0.1:3017', origin: 'http://127.0.0.1:3017', address: '127.0.0.1' }
  assert.equal(isLocalLoginRequest(good), true)
  assert.equal(isLocalLoginRequest({ ...good, address: '' }), false)
  assert.equal(isLocalLoginRequest({ ...good, address: '', devTransport: true }), true)
  assert.equal(isLocalLoginRequest({ ...good, address: '192.168.1.5', devTransport: true }), false)
  for (const bad of [{ enabled: false }, { host: 'evil.test:3017' }, { origin: 'https://evil.test' }, { address: '192.168.1.5' }, { origin: '' }, { origin: 'http://user:pass@127.0.0.1:3017' }]) assert.equal(isLocalLoginRequest({ ...good, ...bad }), false)
})

test('LAN access is opt-in, limited to configured interface addresses and same-origin private peers', () => {
  const lan = { enabled: true, host: '10.0.0.105:3017', origin: 'http://10.0.0.105:3017', address: '10.0.0.42', lanHosts: ['10.0.0.105:3017'] }
  assert.equal(isLocalLoginRequest(lan), true)
  assert.equal(isLocalLoginRequest({ ...lan, address: '::ffff:10.0.0.42' }), true)
  assert.equal(isLocalLoginRequest({ ...lan, address: '', devTransport: true }), true)
  for (const bad of [{ lanHosts: [] }, { enabled: false }, { address: '8.8.8.8' }, { address: '' }, { host: '10.0.0.106:3017' }, { host: '10.0.0.105:3018' }, { origin: 'http://evil.test' }, { origin: 'http://10.0.0.42:3017' }, { origin: '' }]) assert.equal(isLocalLoginRequest({ ...lan, ...bad }), false)
})

test('cookie jars isolate users and only send domain-matching cookies', async () => {
  const seen = []
  const fake = async (url, options) => {
    seen.push([url, options.headers.get('cookie')])
    return new Response('ok', { headers: url.endsWith('/login') ? { 'Set-Cookie': 'private=secret; Secure; HttpOnly; Path=/' } : {} })
  }
  const a = createUpstreamClient(['https://passport2.chaoxing.com', 'https://kb.chaoxing.com'], fake)
  const b = createUpstreamClient(['https://passport2.chaoxing.com'], fake)
  await a.text('https://passport2.chaoxing.com/login')
  await a.text('https://passport2.chaoxing.com/status')
  await a.text('https://kb.chaoxing.com/course')
  await b.text('https://passport2.chaoxing.com/status')
  assert.equal(seen[1][1], 'private=secret')
  assert.equal(seen[2][1], null)
  assert.equal(seen[3][1], null)
  a.close(); b.close()
  await assert.rejects(a.text('https://passport2.chaoxing.com/status'), /SESSION_CLOSED/)
})

test('untrusted redirects are rejected before any request to the target', async () => {
  const seen = []
  const client = createUpstreamClient(['https://auth.wust.edu.cn'], async url => { seen.push(url); return new Response(null, { status: 302, headers: { Location: 'https://evil.test/?ticket=secret' } }) })
  await assert.rejects(client.text('https://auth.wust.edu.cn/start'), /UPSTREAM_NOT_ALLOWED/)
  assert.equal(seen.length, 1)
  client.close()
})

test('Chaoxing login extracts curriculum UUID, projects only course fields', async () => {
  let polls = 0
  const adapter = createLoginAdapter('chaoxing', async (url, options) => {
    const path = new URL(url).pathname
    if (path === '/login') return new Response(['uuid', 'enc', 'doubleFactorLogin', 'forbidotherlogin'].map(k => `<input id="${k}" value="${k === 'uuid' ? 'a'.repeat(32) : '0'}">`).join(''))
    if (path === '/createqr') return new Response(png)
    if (path === '/getauthstatus/v2') {
      assert.equal(new URLSearchParams(options.body).get('uuid'), 'a'.repeat(32))
      return json(++polls === 1 ? { status: false, type: 4 } : { status: true }, { 'Set-Cookie': 'auth=do-not-return; Domain=.chaoxing.com; Secure; Path=/' })
    }
    if (path.endsWith('schedule.html')) return new Response('shell')
    if (path.endsWith('getMyLessons')) {
      assert.equal(options.headers.get('cookie'), 'auth=do-not-return')
      return json({ result: 1, data: { curriculum: { uuid: id, puid: 'private-user', schoolYear: '2026', semester: 1, currentWeek: 4 }, lessonArray: [{ name: '测试课程', teacherName: '老师', location: '测试教室', dayOfWeek: 1, beginNumber: 3, length: 2, weeks: [1, 3], personId: 'private-person' }] } })
    }
    throw new Error('Unexpected request ' + path)
  })
  assert.equal((await adapter.start()).qr, qr)
  assert.equal((await adapter.poll()).state, 'scanned')
  const result = await adapter.poll()
  assert.equal(result.state, 'complete')
  assert.equal(result.result.curriculumUuid, id)
  assert.equal(result.result.lessons[0].weeks, '1,3')
  assert.doesNotMatch(JSON.stringify(result), /do-not-return|private-user|private-person/)
  adapter.close()
})

test('school uses fixed CAS service and never returns authentication material or unknown HTML', async () => {
  const adapter = createLoginAdapter('wust', async (url, options) => {
    const path = new URL(url).pathname
    if (path.endsWith('/login')) return new Response('shell')
    if (path.endsWith('/CreateQRcode')) return json({ uuid: 'random-state', content: qr })
    if (path.endsWith('/CheckScan')) { assert.deepEqual(JSON.parse(options.body), { state: 'random-state' }); return json({ meta: { success: true }, data: { userName: 'private-student', passWord: 'private-secret', service: 'https://evil.test' } }) }
    if (path.endsWith('/tickets')) {
      const form = new URLSearchParams(options.body)
      assert.equal(form.get('service'), 'https://bkjx.wust.edu.cn/jsxsd/')
      assert.equal(form.get('loginType'), '3')
      return json({ tgt: 'private-tgt', ticket: 'private-ticket' })
    }
    if (url.startsWith('https://bkjx.wust.edu.cn/jsxsd/?ticket=')) return new Response('<html>private student account</html>')
    if (path === '/jsxsd/xskb/xskb_list.do') return new Response('<html>private student account</html>')
    throw new Error('Unexpected request')
  })
  await adapter.start()
  const result = await adapter.poll()
  assert.equal(result.state, 'needs_adapter')
  assert.doesNotMatch(JSON.stringify(result), /private-|private student/)
  adapter.close()
})

test('helper uses the documented bearer and never exposes the token', async () => {
  const adapter = createLoginAdapter('helper', async (url, options) => {
    if (url.endsWith('/start')) return json({ code: 200, data: { state: 'state', qr_code: qr } })
    if (url.endsWith('/status')) return json({ code: 200, data: { status: 'success', token: 'private-token', student_id: 'private-id' } })
    assert.equal(options.headers.get('Authorization'), 'Bearer private-token')
    return json({ code: 200, data: [{ className: '测试课程', classroom: '测试教室', weekDay: 2, section: 3, endSection: 4, studentId: 'private-id' }] })
  })
  await adapter.start()
  const result = await adapter.poll()
  assert.equal(result.state, 'complete')
  assert.equal(result.result.lessons[0].name, '测试课程')
  assert.doesNotMatch(JSON.stringify(result), /private-token|private-id/)
  adapter.close()
})

test('sessions isolate owners; completion, cancellation and expiry close credentials', async () => {
  let time = 0, closed = 0
  const store = createLoginStore({ now: () => time, adapterFactory: () => ({ start: async () => ({ state: 'waiting', qr, lifetime: 5000 }), poll: async () => ({ state: 'complete', result: { lessons: [] } }), close: () => { closed++ } }) })
  try {
    await store.start('a', 'chaoxing')
    assert.equal(store.snapshot('b').state, 'idle')
    const complete = await store.poll('a')
    assert.equal(complete.qr, undefined)
    assert.equal(closed, 1)
    time = 6000
    await store.start('b', 'wust')
    store.clear('b')
    assert.equal(closed, 2)
    time = 12000
    await store.start('b', 'helper')
    time = 18000
    assert.equal(store.snapshot('b').state, 'idle')
    assert.equal(closed, 3)
    time = 400000
    assert.equal(store.snapshot('a').result, undefined)
  } finally { store.dispose() }
})

test('late poll results cannot resurrect a cancelled or replaced session', async () => {
  let finish
  const store = createLoginStore({ adapterFactory: () => ({ start: async () => ({ state: 'waiting', qr }), poll: () => new Promise(resolve => { finish = resolve }), close() {} }) })
  try {
    await store.start('a', 'chaoxing')
    const response = store.poll('a')
    store.clear('a')
    finish({ state: 'complete', result: { lessons: [{ name: 'should never appear' }] } })
    assert.equal((await response).state, 'idle')
    assert.equal(store.snapshot('a').result, undefined)
  } finally { store.dispose() }
})

test('polls do not overlap or exceed frequency; second factor stops without fetching courses', async () => {
  let time = 0, polls = 0, closed = 0
  const store = createLoginStore({ now: () => time, adapterFactory: () => ({ start: async () => ({ state: 'waiting', qr }), poll: async () => { polls++; return { state: 'scanned' } }, close() { closed++ } }) })
  try {
    await store.start('a', 'chaoxing')
    await store.poll('a'); await store.poll('a')
    assert.equal(polls, 1)
    time = 3001; await store.poll('a'); assert.equal(polls, 2)
  } finally { store.dispose() }
  assert.equal(closed, 1)
  const a = createLoginAdapter('chaoxing', async url => {
    assert.ok(url.endsWith('/getauthstatus/v2'))
    return json({ status: true, containTwoFactorLogin: true })
  })
  assert.equal((await a.poll()).state, 'needs_action')
  a.close()
})
