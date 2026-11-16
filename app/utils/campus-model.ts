function parsePart(value: unknown) {
  if (!value || typeof value !== 'object'
    || !('path' in value) || typeof value.path !== 'string' || !value.path
    || !('bytes' in value) || typeof value.bytes !== 'number'
    || !Number.isSafeInteger(value.bytes) || value.bytes <= 0) {
    throw new Error('模型分块清单无效')
  }
  return { path: value.path, bytes: value.bytes }
}

export function parseCampusManifest(value: unknown, manifestUrl: string) {
  if (!value || typeof value !== 'object'
    || !('version' in value) || typeof value.version !== 'string' || !value.version
    || !('parts' in value) || !Array.isArray(value.parts) || !value.parts.length) {
    throw new Error('模型版本清单无效')
  }
  const parts = value.parts.map((entry: unknown) => {
    const part = parsePart(entry)
    return { url: new URL(part.path, manifestUrl).href, bytes: part.bytes }
  })
  return { version: value.version, parts }
}

export async function fetchCampusResource(url: string, signal: AbortSignal) {
  const timeout = AbortSignal.timeout(90000)
  const response = await fetch(url, { signal: AbortSignal.any([signal, timeout]) })
  if (!response.ok) throw new Error(`模型请求失败 HTTP ${response.status}`)
  return response.arrayBuffer()
}
