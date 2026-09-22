export class ApiError extends Error {
  status: number
  code: string
  requestId?: string
}
export function createClient(options?: {
  baseUrl?: string
  fetchImpl?: typeof fetch
  timeoutMs?: number
}): { get<T>(path: string, query?: Record<string, string | number | undefined>): Promise<T> }
