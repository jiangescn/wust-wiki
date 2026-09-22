// Shared by Nitro and the local static preview. Fixed upstream, anonymous reads.
const upstream = 'https://api-eat.wustacm.com'
const entity = '[A-Za-z0-9_-]{1,160}'
const routes = [
  [/^canteens$/, []],
  [/^stalls\/feed$/, ['canteenId']],
  [new RegExp(`^stalls/${entity}/dishes$`), []],
  [new RegExp(`^dishes/${entity}$`), []],
  [new RegExp(`^dishes/${entity}/comments$`), ['cursor', 'limit']],
  [/^comments\/feed$/, ['canteenId', 'cursor', 'limit']],
  [/^reputation$/, ['canteenId', 'cursor', 'limit']],
  [/^media\/[a-f0-9-]{36}(?:\/(?:thumbnail|medium))?$/i, []],
]

export function resolveFoodUpstream(requestUrl) {
  const url = new URL(requestUrl, 'http://localhost')
  const path = url.pathname.replace(/^\/api\/food\//, '')
  if (!url.pathname.startsWith('/api/food/') || url.search.length > 2048) return null
  const route = routes.find(([pattern]) => pattern.test(path))
  if (!route) return null
  const target = new URL(`/api/v1/${path}`, upstream)
  for (const [key, value] of url.searchParams) {
    if (!route[1].includes(key) || value.length > 512) return null
    target.searchParams.set(key, value)
  }
  return target
}

export async function fetchFoodResponse(requestUrl, method = 'GET') {
  const error = (status, message) => new Response(JSON.stringify({ error: { code: 'FOOD_API_ERROR', message } }), {
    status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  })
  if (method !== 'GET') return error(405, '此接口仅支持公开数据读取')
  const target = resolveFoodUpstream(requestUrl)
  if (!target) return error(404, '接口不存在')
  try {
    const response = await fetch(target, { headers: { Accept: '*/*' }, redirect: 'error', signal: AbortSignal.timeout(target.pathname.includes('/media/') ? 20000 : 8000) })
    return new Response(response.body, { status: response.status, headers: {
      'Content-Type': response.headers.get('content-type') || 'application/octet-stream',
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    } })
  } catch {
    return error(502, '餐饮数据暂时无法连接，请稍后重试')
  }
}
