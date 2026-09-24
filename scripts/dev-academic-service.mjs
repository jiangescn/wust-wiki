// Local development only: keep login sessions alive across Nuxt hot updates.
// School cookies stay in this process, never on disk. This file is not packaged for deployment.
import { createServer } from 'node:http'
import { stat } from 'node:fs/promises'
import { createAcademicStore } from '../server/utils/academic-store.mjs'
import { createLoginAdapter } from '../server/utils/login-template-adapters.mjs'
const gradeModule = new URL('../server/utils/school-grades.mjs', import.meta.url)
const store = createAcademicStore({ adapterFactory: () => createLoginAdapter('wust', fetch, { authenticateOnly: true, readGrades: async client => {
  const version = (await stat(gradeModule)).mtimeMs
  return (await import(`${gradeModule.href}?v=${version}`)).readSchoolGrades(client)
} }) })
const port = process.env.PORT || '3017'
const origins = new Set([`http://127.0.0.1:${port}`, `http://localhost:${port}`, ...(process.env.WIKI_LOGIN_LAN_HOSTS || '').split(',').filter(Boolean).map(host => 'http://' + host)])
const server = createServer(async (req, res) => {
  const send = (status, data) => { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)) }
  if (req.method !== 'POST' || req.url !== '/api/academic' || !origins.has(req.headers.origin)) return send(403, {})
  try {
    let raw = ''
    for await (const chunk of req) { raw += chunk; if (raw.length > 2048) return send(413, {}) }
    const reply = await store.handle({ body: JSON.parse(raw), authorization: req.headers.authorization, origin: req.headers.origin })
    send(reply.status, reply.data)
  } catch { send(502, { message: '本地查询服务暂不可用。' }) }
})
server.listen(Number(process.env.WIKI_ACADEMIC_DEV_PORT), '127.0.0.1', () => console.log('Local academic session service ready'))
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { store.dispose(); server.close(); server.closeAllConnections() })
