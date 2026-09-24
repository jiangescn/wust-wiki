import { createAcademicStore } from '../utils/academic-store.mjs'
import { isLocalLoginRequest } from '../utils/login-template-store.mjs'

const store = createAcademicStore()
export default defineEventHandler(async event => {
  setResponseHeaders(event, { 'Cache-Control': 'private, no-store', 'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff' })
  const origin = getHeader(event, 'origin') || ''
  if (!isLocalLoginRequest({ enabled: process.env.WIKI_LOGIN_TEMPLATES === '1', host: getHeader(event, 'host') || '', origin, address: event.node.req.socket.remoteAddress || '', devTransport: import.meta.dev, lanHosts: (process.env.WIKI_LOGIN_LAN_HOSTS || '').split(',').filter(Boolean) })) throw createError({ statusCode: 403, statusMessage: 'Local login not enabled' })
  if (Number(getHeader(event, 'content-length') || 0) > 2048) throw createError({ statusCode: 413, statusMessage: 'Request too large' })
  const raw = await readRawBody(event)
  if (!raw || raw.length > 2048 || !getHeader(event, 'content-type')?.startsWith('application/json')) throw createError({ statusCode: 400, statusMessage: 'Invalid request' })
  let body: unknown
  try { body = JSON.parse(raw) } catch { throw createError({ statusCode: 400, statusMessage: 'Invalid JSON' }) }
  if (import.meta.dev && /^\d{4,5}$/.test(process.env.WIKI_ACADEMIC_DEV_PORT || '')) {
    const response = await fetch(`http://127.0.0.1:${process.env.WIKI_ACADEMIC_DEV_PORT}/api/academic`, { method: 'POST', headers: { 'Content-Type': 'application/json', Origin: origin, Authorization: getHeader(event, 'authorization') || '' }, body: raw, signal: AbortSignal.timeout(45_000) })
    setResponseStatus(event, response.status)
    return response.json()
  }
  const result = await store.handle({ body, origin, authorization: getHeader(event, 'authorization') })
  setResponseStatus(event, result.status)
  return result.data
})
