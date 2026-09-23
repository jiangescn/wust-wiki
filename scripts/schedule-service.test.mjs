import test from 'node:test'
import assert from 'node:assert/strict'
import { once } from 'node:events'
import { request } from 'node:http'
import { createScheduleServer } from '../server/schedule-service.mjs'
import { createLoginStore } from '../server/utils/login-template-store.mjs'

// Use raw HTTP so the test can explicitly exercise reverse-proxy Host headers.
function fetch(url, options = {}) {
  return new Promise((resolveResponse, reject) => {
    const req = request(url, options, res => {
      const chunks = []
      res.on('data', chunk => chunks.push(chunk))
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8')
        const headers = new Headers(Object.entries(res.headers).map(([k, v]) => [k, Array.isArray(v) ? v.join(',') : v]))
        resolveResponse({ status: res.statusCode, headers, text: async () => text, json: async () => JSON.parse(text) })
      })
    })
    req.on('error', reject)
    if (options.body) { req.setHeader('Content-Length', Buffer.byteLength(options.body)); req.write(options.body) }
    req.end()
  })
}

test('deployed service requires exact HTTPS origin, serves only school login, isolates sessions and limits new sessions per client', async () => {
  const origin = 'https://schedule.example.test'
  let starts = 0, time = Date.now()
  const store = createLoginStore({ adapterFactory: () => ({ start: async () => { starts++; return { state: 'waiting', qr: 'fixture' } }, poll: async () => ({ state: 'waiting' }), close() {} }) })
  const server = createScheduleServer({ origin, allowedOrigins: ['https://wiki.example.org'], store, now: () => time })
  server.listen(0, '127.0.0.1'); await once(server, 'listening')
  const base = `http://127.0.0.1:${server.address().port}`
  const post = (body, extra = {}) => fetch(base + '/api/login-template', { method: 'POST', headers: { Host: 'schedule.example.test', Origin: 'https://wiki.example.org', 'Content-Type': 'application/json', 'X-Real-IP': '192.0.2.1', ...extra }, body: JSON.stringify(body) })
  try {
    for (const Origin of ['', 'http://schedule.example.test', 'https://evil.test', origin + '/']) assert.equal((await post({ action: 'inspect' }, { Origin })).status, 403)
    assert.equal((await post({ action: 'inspect' }, { Host: 'evil.test' })).status, 403)
    const inspect = await post({ action: 'inspect' })
    const initial = await inspect.json()
    assert.deepEqual(initial.providers.map(p => p.id), ['wust'])
    assert.equal(inspect.headers.get('set-cookie'), null)
    assert.equal(inspect.headers.get('access-control-allow-origin'), 'https://wiki.example.org')
    assert.match(initial.sessionToken, /^[a-f\d]{64}$/)
    const Authorization = 'Bearer ' + initial.sessionToken
    assert.equal((await post({ action: 'start', provider: 'helper' }, { Authorization })).status, 400)
    assert.equal((await post({ action: 'start', provider: 'wust' }, { Authorization })).status, 200)
    assert.equal((await (await post({ action: 'inspect' }, { Authorization })).json()).state, 'waiting')
    assert.equal((await (await post({ action: 'inspect' })).json()).state, 'idle')
    for (let n = 0; n < 5; n++) assert.equal((await post({ action: 'start', provider: 'wust' })).status, 200)
    assert.equal((await post({ action: 'start', provider: 'wust' })).status, 429)
    assert.equal(starts, 6)
    assert.equal((await post({ action: 'inspect', excess: 'x'.repeat(3000) })).status, 413)
    assert.equal((await post({ action: 'clear' }, { Authorization, 'X-Real-IP': '192.0.2.2' })).status, 200)
    assert.equal((await post({ action: 'inspect' }, { Authorization, 'X-Real-IP': '192.0.2.2' })).status, 401)
    const fresh = await (await post({ action: 'inspect' })).json()
    assert.equal((await post({ action: 'poll' }, { Authorization: 'Bearer ' + fresh.sessionToken, Origin: origin })).status, 401)
    time += 600001
    assert.equal((await post({ action: 'poll' }, { Authorization: 'Bearer ' + fresh.sessionToken })).status, 401)
  } finally { await new Promise(resolve => server.close(resolve)) }
})

test('API-only deployment supports approved Wiki preflight and exposes no website', async () => {
  const server = createScheduleServer({ origin: 'https://schedule.example.test', allowedOrigins: ['https://wiki.example.org'] })
  server.listen(0, '127.0.0.1'); await once(server, 'listening')
  const base = 'http://127.0.0.1:' + server.address().port
  const get = path => fetch(base + path, { headers: { Host: 'schedule.example.test' } })
  try {
    assert.equal((await (await get('/')).json()).service, 'wust-school-schedule-api')
    for (const path of ['/previews/schedule-login', '/_nuxt/app.js', '/.env', '/study']) assert.equal((await get(path)).status, 404)
    const preflight = await fetch(base + '/api/login-template', { method: 'OPTIONS', headers: { Host: 'schedule.example.test', Origin: 'https://wiki.example.org', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,content-type' } })
    assert.equal(preflight.status, 204)
    assert.equal(preflight.headers.get('access-control-allow-origin'), 'https://wiki.example.org')
    assert.match(preflight.headers.get('access-control-allow-headers'), /Authorization/)
    assert.equal(preflight.headers.get('access-control-allow-credentials'), null)
  } finally { await new Promise(resolve => server.close(resolve)) }
})
