import { randomBytes } from 'node:crypto'
import { createLoginStore, isLocalLoginRequest, type LoginProvider } from '../utils/login-template-store.mjs'

const store = createLoginStore()
const cookie = 'wiki_login_template'
const options = { httpOnly: true, sameSite: 'strict' as const, path: '/api/login-template', maxAge: 600 }

export default defineEventHandler(async event => {
  setResponseHeaders(event, { 'Cache-Control': 'private, no-store', 'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff' })
  // Nuxt dev may omit the socket address. LAN targets are explicit local-interface
  // host:port pairs from the launcher; Origin must still match. Never trust forwarded headers.
  if (!isLocalLoginRequest({ enabled: process.env.WIKI_LOGIN_TEMPLATES === '1', host: getHeader(event, 'host') || '', origin: getHeader(event, 'origin') || '', address: event.node.req.socket.remoteAddress || '', devTransport: import.meta.dev, lanHosts: (process.env.WIKI_LOGIN_LAN_HOSTS || '').split(',').filter(Boolean) })) {
    throw createError({ statusCode: 403, statusMessage: 'Login template address not allowed; use dev:login or dev:login:lan' })
  }
  if (Number(getHeader(event, 'content-length') || 0) > 2048 || !getHeader(event, 'content-type')?.startsWith('application/json')) throw createError({ statusCode: 400, statusMessage: 'Invalid request' })
  const raw = await readRawBody(event)
  if (!raw || raw.length > 2048) throw createError({ statusCode: 400, statusMessage: 'Invalid request' })
  let body: { action?: string; provider?: LoginProvider }
  try { body = JSON.parse(raw) } catch { throw createError({ statusCode: 400, statusMessage: 'Invalid request' }) }
  if (!body || !['start', 'poll', 'clear', 'inspect'].includes(body.action || '')) throw createError({ statusCode: 400, statusMessage: 'Invalid action' })
  let owner = getCookie(event, cookie) || ''
  if (!/^[a-f\d]{64}$/.test(owner)) owner = randomBytes(32).toString('hex')
  // Refresh while in use. This cookie only identifies a local template session.
  setCookie(event, cookie, owner, { ...options, secure: getRequestURL(event).protocol === 'https:' })
  if (body.action === 'clear') { store.clear(owner); deleteCookie(event, cookie, { path: options.path }); return { state: 'idle', message: '临时会话与当前结果已清除。' } }
  if (body.action === 'inspect') return { ...store.snapshot(owner), providers: store.providers }
  try {
    if (body.action === 'start') return await store.start(owner, body.provider!)
    return await store.poll(owner)
  } catch { throw createError({ statusCode: 400, statusMessage: 'Invalid provider or local session capacity reached' }) }
})
