import { createServer } from 'node:http'
import { randomBytes } from 'node:crypto'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { isIP } from 'node:net'
import { createLoginStore } from './utils/login-template-store.mjs'
import { createAcademicStore } from './utils/academic-store.mjs'

const apiPath = '/api/login-template'

function readBody(request) {
  return new Promise((resolveBody, reject) => {
    let size = 0
    const chunks = []
    request.on('data', chunk => {
      size += chunk.length
      if (size <= 2048) chunks.push(chunk)
    })
    request.on('end', () => size > 2048 ? reject(new Error('BODY_LIMIT')) : resolveBody(Buffer.concat(chunks).toString('utf8')))
    request.on('error', reject)
  })
}

// A single process behind the existing HTTPS reverse proxy. Upstream auth logic
// is shared with the local template; no credentials or course data go to disk.
export function createScheduleServer({ origin, allowedOrigins = [], store = createLoginStore(), academicStore = createAcademicStore(), now = Date.now }) {
  const site = new URL(origin)
  if (site.protocol !== 'https:' || site.origin !== origin || site.username || site.password) throw new Error('SCHEDULE_ORIGIN must be an exact HTTPS origin')
  const origins = new Set([origin, ...allowedOrigins])
  for (const value of origins) { const url = new URL(value); if (url.protocol !== 'https:' || url.origin !== value) throw new Error('Allowed origins must be exact HTTPS origins') }
  const clients = new Map()
  const browserSessions = new Map()
  const providers = store.providers.filter(p => p.id === 'wust')
  const sweep = () => {
    for (const [key, value] of clients) if (now() >= value.until) clients.delete(key)
    for (const [key, value] of browserSessions) if (now() >= value.until) { browserSessions.delete(key); store.clear(key) }
  }
  const cleanup = setInterval(sweep, 60_000)
  cleanup.unref()
  function allow(request, start) {
    sweep()
    // The dedicated loopback-only proxy overwrites this header, never appends it.
    const supplied = request.headers['x-real-ip']
    const peer = typeof supplied === 'string' && isIP(supplied) ? supplied : request.socket.remoteAddress
    if (!clients.has(peer)) {
      if (clients.size >= 2048) return false
      clients.set(peer, { until: now() + 60_000, requests: 0, starts: 0 })
    }
    const entry = clients.get(peer)
    if (!start) entry.requests++
    if (start) entry.starts++
    return entry.requests <= 180 && (!start || entry.starts <= 6)
  }
  const server = createServer(async (request, response) => {
    response.setHeader('X-Content-Type-Options', 'nosniff')
    response.setHeader('Referrer-Policy', 'no-referrer')
    response.setHeader('X-Frame-Options', 'DENY')
    response.setHeader('Cache-Control', 'private, no-store')
    response.setHeader('X-Robots-Tag', 'noindex, nofollow')
    const json = (status, body) => { response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); response.end(JSON.stringify(body)) }
    try {
      const path = new URL(request.url, origin).pathname
      if (path === '/healthz' && request.method === 'GET') return json(200, { status: 'ok' })
      if (request.headers.host !== site.host) return json(403, { error: 'Host not allowed' })
      if (path === apiPath || path === '/api/academic') {
        if (!origins.has(request.headers.origin)) return json(403, { error: 'Origin not allowed' })
        response.setHeader('Access-Control-Allow-Origin', request.headers.origin)
        response.setHeader('Vary', 'Origin')
        if (request.method === 'OPTIONS') {
          if (request.headers['access-control-request-method'] !== 'POST') return json(405, { error: 'POST required' })
          response.writeHead(204, { 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Max-Age': '600' })
          response.end(); return
        }
        if (request.method !== 'POST') return json(405, { error: 'POST required' })
        if (!request.headers['content-type']?.startsWith('application/json')) return json(400, { error: 'JSON required' })
        if (!allow(request, false)) { response.setHeader('Retry-After', '60'); return json(429, { error: 'Too many requests' }) }
        if (Number(request.headers['content-length'] || 0) > 2048) return json(413, { error: 'Body too large' })
        let body
        try { body = JSON.parse(await readBody(request)) } catch { return json(400, { error: 'Invalid body' }) }
        if (path === '/api/academic') {
          if (body?.action === 'start' && !allow(request, true)) { response.setHeader('Retry-After', '60'); return json(429, { message: '请求较多，请一分钟后重试。' }) }
          const result = await academicStore.handle({ body, authorization: request.headers.authorization, origin: request.headers.origin })
          return json(result.status, result.data)
        }
        if (!body || !['inspect', 'start', 'poll', 'clear'].includes(body.action)) return json(400, { error: 'Invalid action' })
        if (body.action === 'start' && body.provider !== 'wust') return json(400, { error: 'Only school login is enabled' })
        if (body.action === 'start' && !allow(request, true)) { response.setHeader('Retry-After', '60'); return json(429, { error: 'Too many login attempts' }) }
        // A random capability for this API session, not a school credential.
        // Required for cross-site static Wikis where third-party cookies may be blocked.
        const authorization = request.headers.authorization || ''
        let owner = /^Bearer ([a-f\d]{64})$/.exec(authorization)?.[1] || ''
        let session = browserSessions.get(owner)
        if (authorization && (!session || session.origin !== request.headers.origin)) return json(401, { error: 'Session expired or invalid' })
        if (body.action === 'clear') { store.clear(owner); browserSessions.delete(owner); return json(200, { state: 'idle', message: '临时会话与当前结果已清除。' }) }
        if (!session && !['inspect', 'start'].includes(body.action)) return json(401, { error: 'Session required' })
        if (!session) {
          if (browserSessions.size >= 2048) return json(503, { error: 'Session capacity reached' })
          owner = randomBytes(32).toString('hex')
          session = { origin: request.headers.origin, until: now() + 600_000 }
          browserSessions.set(owner, session)
        }
        if (body.action === 'inspect') return json(200, { ...store.snapshot(owner), providers, deployment: true, sessionToken: owner })
        try { return json(200, { ...(body.action === 'start' ? await store.start(owner, 'wust') : await store.poll(owner)), sessionToken: owner }) }
        catch { return json(503, { error: 'Session capacity reached; retry later' }) }
      }
      if (path === '/' && request.method === 'GET') return json(200, { service: 'wust-school-schedule-api', status: 'ok' })
      return json(404, { error: 'Not found' })
    } catch { if (!response.headersSent) json(404, { error: 'Not found' }); else response.end() }
  })
  server.requestTimeout = 15_000
  server.headersTimeout = 10_000
  server.on('close', () => { clearInterval(cleanup); browserSessions.clear(); clients.clear(); store.dispose(); academicStore.dispose() })
  return server
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const server = createScheduleServer({ origin: process.env.SCHEDULE_ORIGIN, allowedOrigins: (process.env.SCHEDULE_ALLOWED_ORIGINS || '').split(',').filter(Boolean) })
  server.listen(Number(process.env.PORT || 3000), process.env.HOST || '127.0.0.1', () => console.log('School schedule service ready'))
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => { server.close(); server.closeAllConnections() })
}
