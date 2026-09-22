import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolveFoodUpstream, fetchFoodResponse } from '../server/utils/food-proxy.mjs'

test('public reads target the fixed API and preserve opaque cursors', () => {
  const url = resolveFoodUpstream('/api/food/dishes/dish-example/comments?limit=12&cursor=abc%2B%2F%3D')
  assert.equal(url.origin, 'https://api-eat.wustacm.com')
  assert.equal(url.pathname, '/api/v1/dishes/dish-example/comments')
  assert.equal(url.searchParams.get('cursor'), 'abc+/=')
  assert.equal(resolveFoodUpstream('/api/food/stalls/feed?canteenId=canteen-nanyuan').pathname, '/api/v1/stalls/feed')
  assert.equal(resolveFoodUpstream('/api/food/stalls/stall-example/dishes').pathname, '/api/v1/stalls/stall-example/dishes')
})

test('private routes, arbitrary targets and unapproved parameters cannot pass through', async () => {
  for (const path of ['/api/food/auth/wechat', '/api/food/me', '/api/food/admin/dishes/abc', '/api/food/https://example.com', '/api/food/dishes?url=https://example.com', '/api/food/dishes?userId=abc', '/api/food/media/not-a-uuid', '/api/food/%2e%2e/auth/wechat']) {
    assert.equal(resolveFoodUpstream(path), null, path)
  }
  assert.equal((await fetchFoodResponse('/api/food/canteens', 'POST')).status, 405)
})

test('upstream credentials are omitted and media is never cached', async (t) => {
  let options
  t.mock.method(globalThis, 'fetch', async (_url, init) => {
    options = init
    return new Response(new Uint8Array([1, 2, 3]), { headers: { 'Content-Type': 'image/webp', 'Set-Cookie': 'private=value', 'Cache-Control': 'public, max-age=3600' } })
  })
  const response = await fetchFoodResponse('/api/food/media/6499a73f-44bc-442a-aff8-90bdeadbe62e/thumbnail')
  assert.equal(new Headers(options.headers).has('authorization'), false)
  assert.equal(new Headers(options.headers).has('cookie'), false)
  assert.equal(options.redirect, 'error')
  assert.equal(response.headers.get('cache-control'), 'private, no-store')
  assert.equal(response.headers.has('set-cookie'), false)
  assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [1, 2, 3])
})

test('network errors become a recoverable API error without internal details', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('internal upstream details') })
  const response = await fetchFoodResponse('/api/food/canteens')
  assert.equal(response.status, 502)
  assert.equal((await response.json()).error.message, '餐饮数据暂时无法连接，请稍后重试')
})
