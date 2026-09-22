/** Framework-free browser/Node HTTP boundary. baseUrl must include /api/v1. */
export class ApiError extends Error {
  constructor(message, status = 0, code = 'NETWORK_ERROR', requestId) {
    super(message); this.name = 'ApiError'; this.status = status; this.code = code; this.requestId = requestId;
  }
}
export function createClient({ baseUrl = '/api/v1', fetchImpl = globalThis.fetch, timeoutMs = 10000 } = {}) {
  async function get(path, query = {}) {
    if (!path.startsWith('/') || path.startsWith('//')) throw new TypeError('Expected relative API path');
    const search = new URLSearchParams();
    for (const [key, value] of Object.entries(query)) if (value !== undefined && value !== '') search.set(key, String(value));
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(`${baseUrl.replace(/\/$/, '')}${path}${search.size ? '?' + search : ''}`, {
        headers: { Accept: 'application/json' }, signal: controller.signal, credentials: 'omit',
      });
      let body;
      try { body = await response.json(); } catch { throw new ApiError('服务返回了无效的 JSON', response.status, 'INVALID_RESPONSE'); }
      if (!response.ok) throw new ApiError(body.error?.message || '请求失败', response.status, body.error?.code || 'HTTP_ERROR', body.error?.requestId);
      if (!Object.hasOwn(body, 'data')) throw new ApiError('服务响应缺少 data', response.status, 'INVALID_RESPONSE');
      return body.data;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(controller.signal.aborted ? '请求超时，请重试' : '网络连接失败，请重试');
    } finally { clearTimeout(timer); }
  }
  const id = encodeURIComponent;
  return {
    get,
    canteens: () => get('/canteens'),
    dishes: query => get('/dishes/feed', query),
    dish: value => get(`/dishes/${id(value)}`),
    stall: value => get(`/stalls/${id(value)}`),
    stallDishes: value => get(`/stalls/${id(value)}/dishes`),
    comments: (value, query) => get(`/dishes/${id(value)}/comments`, query),
    rating: value => get(`/dishes/${id(value)}/rating`),
    search: q => get('/search', { q }),
    reputation: query => get('/reputation', query),
    announcements: () => get('/announcements'),
  };
}
