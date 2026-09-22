import { createServer } from 'node:http'
import { readFile, stat } from 'node:fs/promises'
import { resolve, sep, extname } from 'node:path'
import { Readable } from 'node:stream'
import { pipeline } from 'node:stream/promises'
import { fetchFoodResponse } from '../server/utils/food-proxy.mjs'

const root = resolve('.output/public')
const port = Number(process.env.PORT || 4173)
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.png': 'image/png', '.webp': 'image/webp', '.wasm': 'application/wasm', '.txt': 'text/plain; charset=utf-8', '.xml': 'application/xml' }
await stat(resolve(root, 'index.html'))
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname)
    if (pathname.startsWith('/api/food/')) {
      const result = await fetchFoodResponse(request.url, request.method)
      response.writeHead(result.status, Object.fromEntries(result.headers))
      if (result.body) {
        const source = Readable.fromWeb(result.body)
        // Keep ownership of late upstream errors after a browser cancels a response.
        source.on('error', () => response.destroy())
        await pipeline(source, response)
      } else response.end()
      return
    }
    let path = resolve(root, '.' + pathname)
    if (path !== root && !path.startsWith(root + sep)) { response.writeHead(403).end(); return }
    if ((await stat(path)).isDirectory()) path = resolve(path, 'index.html')
    const body = await readFile(path)
    response.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream', 'Cache-Control': 'no-store' })
    response.end(request.method === 'HEAD' ? undefined : body)
  } catch {
    if (response.headersSent) { response.destroy(); return }
    response.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' })
    response.end(await readFile(resolve(root, '404.html')))
  }
})
server.listen(port, '127.0.0.1', () => console.log(`Static preview: http://127.0.0.1:${server.address().port}`))
