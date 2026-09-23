import { CookieJar } from 'tough-cookie'

// Each login has a separate in-memory RFC cookie jar. Never serialize it.
export function createUpstreamClient(origins, fetchImpl = fetch) {
  const jar = new CookieJar()
  let closed = false
  const controllers = new Set()
  const allowed = new Set(origins)
  async function request(input, options = {}) {
    if (closed) throw new Error('SESSION_CLOSED')
    let url = new URL(input)
    let method = options.method || 'GET'
    let body = options.body
    const controller = new AbortController()
    controllers.add(controller)
    const timeout = setTimeout(() => controller.abort(), 15000)
    try {
      for (let hop = 0; hop < 8; hop++) {
        if (closed || !allowed.has(url.origin) || url.username || url.password) throw new Error('UPSTREAM_NOT_ALLOWED')
        const headers = new Headers(options.headers)
        headers.set('Accept', headers.get('Accept') || '*/*')
        const cookie = await jar.getCookieString(url.href)
        if (cookie) headers.set('Cookie', cookie)
        else headers.delete('Cookie')
        const response = await fetchImpl(url.href, { method, body, headers, redirect: 'manual', signal: controller.signal })
        if (closed) throw new Error('SESSION_CLOSED')
        for (const value of response.headers.getSetCookie()) await jar.setCookie(value, url.href)
        if ([301, 302, 303, 307, 308].includes(response.status)) {
          const target = response.headers.get('location')
          await response.body?.cancel()
          if (!target) throw new Error('UPSTREAM_REDIRECT')
          const next = new URL(target, url)
          // No cross-origin credential forwarding; adapters may explicitly call another origin.
          if (next.origin !== url.origin && (options.headers?.Authorization || method !== 'GET')) throw new Error('UPSTREAM_REDIRECT')
          url = next
          if (response.status === 303 || ([301, 302].includes(response.status) && method === 'POST')) { method = 'GET'; body = undefined }
          continue
        }
        if (!response.ok) { await response.body?.cancel(); throw new Error('UPSTREAM_HTTP') }
        // Bound upstream bodies, including QR images and HTML, before parsing.
        const reader = response.body?.getReader()
        const chunks = []
        let size = 0
        if (reader) while (true) {
          const { done, value } = await reader.read()
          if (done) break
          size += value.length
          if (size > 2_000_000) { await reader.cancel(); throw new Error('UPSTREAM_TOO_LARGE') }
          chunks.push(Buffer.from(value))
        }
        return { url: url.href, headers: response.headers, bytes: Buffer.concat(chunks) }
      }
      throw new Error('UPSTREAM_REDIRECT')
    } finally { clearTimeout(timeout); controllers.delete(controller) }
  }
  return {
    request,
    async text(url, options) { return (await request(url, options)).bytes.toString('utf8') },
    async json(url, options) { return JSON.parse((await request(url, options)).bytes.toString('utf8')) },
    close() { closed = true; for (const c of controllers) c.abort(); jar.removeAllCookiesSync() },
  }
}

export const form = values => ({ method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(values).toString() })
export const jsonPost = values => ({ method: 'POST', headers: { 'Content-Type': 'application/json', Platform: 'android' }, body: JSON.stringify(values) })

export function pngData(value) {
  if (typeof value !== 'string' || value.length > 700_000 || !/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(value)) throw new Error('QR_FORMAT_CHANGED')
  const bytes = Buffer.from(value.split(',')[1], 'base64')
  if (!bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) throw new Error('QR_FORMAT_CHANGED')
  return value
}

export function inputValue(html, name) {
  for (const tag of html.matchAll(/<input\b[^>]*>/gi)) {
    const attrs = Object.fromEntries([...tag[0].matchAll(/([\w-]+)=["']([^"']*)["']/g)].map(m => [m[1], m[2]]))
    if (attrs.id === name) return attrs.value || ''
  }
  throw new Error('LOGIN_PAGE_CHANGED')
}
