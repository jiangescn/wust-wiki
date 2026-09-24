import { randomBytes } from 'node:crypto'
import { createLoginAdapter } from './login-template-adapters.mjs'

export const ACADEMIC_TTL = 24 * 60 * 60 * 1000
export function createAcademicStore({ adapterFactory = () => createLoginAdapter('wust', fetch, { authenticateOnly: true }), now = Date.now } = {}) {
  const sessions = new Map()
  function remove(token) { const s = sessions.get(token); sessions.delete(token); s?.adapter.close() }
  function sweep() { for (const [token, s] of sessions) if (now() >= s.expiresAt) remove(token) }
  const timer = setInterval(sweep, 10_000); timer.unref?.()
  const view = s => ({ state: s.state, message: s.message || '', expiresAt: s.expiresAt, ...(s.qr ? { qr: s.qr } : {}) })
  return {
    dispose() { clearInterval(timer); for (const token of sessions.keys()) remove(token) },
    async handle({ body, authorization = '', origin }) {
      sweep()
      const reply = (status, data) => ({ status, data })
      if (!body || !['start', 'poll', 'inspect', 'query', 'logout'].includes(body.action)) return reply(400, { message: '无效请求。' })
      if (body.action === 'query' && !['grades', 'schedule'].includes(body.resource)) return reply(400, { message: '无效查询。' })
      const token = /^Bearer ([a-f\d]{64})$/.exec(authorization)?.[1]
      if (body.action === 'start') {
        if (authorization) return reply(400, { message: '请先退出当前会话。' })
        if (sessions.size >= 200 || [...sessions.values()].filter(s => s.state !== 'authenticated').length >= 20) return reply(503, { message: '当前登录人数较多，请稍后重试。' })
        const next = randomBytes(32).toString('hex')
        const s = { origin, adapter: adapterFactory(), state: 'creating', expiresAt: now() + 180_000, lastPoll: -Infinity, cache: new Map() }
        sessions.set(next, s)
        try {
          const data = await s.adapter.start()
          if (sessions.get(next) !== s || now() >= s.expiresAt) { remove(next); return reply(401, { message: '会话已过期。' }) }
          Object.assign(s, { state: data.state, message: data.message, qr: data.qr })
          return reply(200, { ...view(s), sessionToken: next })
        } catch { remove(next); return reply(502, { message: '未能获取学校二维码，请重试。' }) }
      }
      const s = sessions.get(token)
      if (!s || s.origin !== origin) return reply(401, { message: '登录已到期，请重新扫码。' })
      if (body.action === 'logout') { remove(token); return reply(200, { state: 'idle', message: '' }) }
      if (body.action === 'inspect') return reply(200, view(s))
      if (body.action === 'poll') {
        if (!['waiting', 'scanned'].includes(s.state) || s.busy || now() - s.lastPoll < 3000) return reply(200, view(s))
        s.lastPoll = now(); s.busy = true
        try {
          const data = await s.adapter.poll()
          if (sessions.get(token) !== s || now() >= s.expiresAt) { remove(token); return reply(401, { message: '扫码会话已过期，请重试。' }) }
          s.state = data.state; s.message = data.message
          if (s.state === 'authenticated') { s.expiresAt = now() + ACADEMIC_TTL; delete s.qr }
          else if (!['waiting', 'scanned'].includes(s.state)) remove(token)
          return reply(200, view(s))
        } catch { remove(token); return reply(502, { message: '学校认证暂不可用，请重新扫码。' }) }
        finally { s.busy = false }
      }
      if (s.state !== 'authenticated') return reply(409, { message: '请先完成扫码。' })
      const cached = s.cache.get(body.resource)
      if (cached && now() - cached.at < 60_000) return reply(200, { ...view(s), ...cached.data })
      if (s.busy) return reply(409, { message: '正在查询，请稍后重试。' })
      s.busy = true
      try {
        const data = await s.adapter.read(body.resource)
        if (sessions.get(token) !== s || now() >= s.expiresAt) { remove(token); return reply(401, { message: '登录已到期，请重新扫码。' }) }
        if (data.state === 'needs_action') { remove(token); return reply(401, { message: data.message }) }
        if (data.state === 'complete') s.cache.set(body.resource, { at: now(), data: { ...data, fetchedAt: now() } })
        return reply(200, { ...view(s), ...data, fetchedAt: s.cache.get(body.resource)?.data.fetchedAt })
      } catch { return reply(502, { message: '教务系统暂时无法查询，请稍后重试。' }) }
      finally { s.busy = false }
    },
  }
}
