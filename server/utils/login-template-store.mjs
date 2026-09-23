import { createLoginAdapter, templateProviders } from './login-template-adapters.mjs'

const pending = new Set(['waiting', 'scanned'])
export function isLocalLoginRequest({ enabled, host, origin, address, devTransport = false, lanHosts = [] }) {
  if (!enabled) return false
  try {
    const target = new URL('http://' + host)
    const source = new URL(origin)
    const privateIPv4 = ip => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip)
    const lanTarget = lanHosts.includes(target.host) && privateIPv4(target.hostname)
    const peer = address.replace(/^::ffff:/, '')
    const allowedPeer = ['127.0.0.1', '::1'].includes(peer) || (lanTarget && privateIPv4(peer)) || (devTransport && !address)
    return allowedPeer && (['127.0.0.1', 'localhost', '[::1]'].includes(target.hostname) || lanTarget)
      && !target.username && !target.password
      && source.host === target.host && ['http:', 'https:'].includes(source.protocol)
      && !source.username && !source.password
  } catch { return false }
}

export function createLoginStore({ adapterFactory = createLoginAdapter, now = Date.now } = {}) {
  const sessions = new Map()
  const started = new Map()
  const release = s => { s.adapter?.close(); s.adapter = undefined; delete s.qr }
  function expire(s) {
    release(s)
    delete s.result
    s.state = 'expired'
    s.message = '会话已到期，临时数据已清除。请重新生成二维码。'
  }
  function sweep() {
    const time = now()
    for (const [key, s] of sessions) if (time >= s.expiresAt) { expire(s); sessions.delete(key) }
    for (const [key, time] of started) if (now() - time >= 60_000) started.delete(key)
  }
  const timer = setInterval(sweep, 10_000)
  timer.unref?.()
  const view = s => s ? { provider: s.provider, state: s.state, message: s.message, qr: s.qr, expiresAt: s.expiresAt, result: s.result } : { state: 'idle', message: '尚未创建二维码，或临时会话已清除。' }
  const current = (owner, s) => sessions.get(owner) === s && now() < s.expiresAt
  function clear(owner) { const s = sessions.get(owner); if (s) release(s); sessions.delete(owner); return view() }
  return {
    providers: templateProviders,
    clear,
    dispose() { clearInterval(timer); for (const owner of sessions.keys()) clear(owner); started.clear() },
    snapshot(owner) { sweep(); return view(sessions.get(owner)) },
    async start(owner, provider) {
      sweep()
      if (!templateProviders.some(p => p.id === provider)) throw new Error('UNKNOWN_PROVIDER')
      if (now() - (started.get(owner) ?? -Infinity) < 5000) return { state: 'throttled', message: '请等待五秒后再生成二维码。' }
      if (sessions.size >= 20 && !sessions.has(owner)) throw new Error('CAPACITY')
      if (started.size >= 100 && !started.has(owner)) throw new Error('CAPACITY')
      clear(owner)
      started.set(owner, now())
      const s = { provider, state: 'creating', message: '正在获取二维码。', expiresAt: now() + 180_000, adapter: adapterFactory(provider), busy: true, lastPoll: -Infinity }
      sessions.set(owner, s)
      try {
        const result = await s.adapter.start()
        if (!current(owner, s)) return view(sessions.get(owner))
        Object.assign(s, result, { expiresAt: now() + Math.min(result.lifetime || 150_000, 180_000) })
      } catch {
        if (current(owner, s)) { release(s); s.state = 'error'; s.message = '未能创建二维码：上游暂不可用或接口格式已变化。可以重新生成或使用官方入口。' }
      } finally { s.busy = false }
      return view(sessions.get(owner))
    },
    async poll(owner) {
      sweep()
      const s = sessions.get(owner)
      if (!s || !pending.has(s.state) || s.busy || now() - s.lastPoll < 3000) return view(s)
      s.busy = true
      s.lastPoll = now()
      try {
        const result = await s.adapter.poll()
        if (!current(owner, s)) return view(sessions.get(owner))
        Object.assign(s, result)
        if (!pending.has(s.state)) { release(s); s.expiresAt = now() + 300_000 }
      } catch {
        if (current(owner, s)) { release(s); s.state = 'error'; s.message = '登录查询失败，临时会话已清除。请重试或在官方页面完成认证。' }
      } finally { s.busy = false }
      return view(sessions.get(owner))
    },
  }
}
