// Local-only, fictional responses for browser QA. Never included in backend releases.
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
const lessons = [
  { name: '验收课程 A', teacher: '测试教师', location: '测试教室', day: 1, sections: '1-2', weeks: '1-16' },
  { name: '验收课程 B', teacher: '测试教师', location: '测试机房', day: 1, sections: '2-3', weeks: '2-16双' },
  { name: '验收课程 C', teacher: '', location: '', day: 3, sections: '7,9', weeks: '2,4-5' },
  { name: '周次待确认课程', teacher: '', location: '', day: 4, sections: '3-4', weeks: '另行通知' },
  { name: '未排时间课程', teacher: '', location: '', weeks: '1-16' },
  { name: '晚间课程', teacher: '', location: '在线', day: 7, sections: '12', weeks: '1-15单' },
]
const counts = { start: 0, poll: 0, clear: 0 }
let startedAt = 0, firstPollDelayMs
let waitingView
const server = createServer(async (req, res) => {
  res.setHeader('Cache-Control', 'no-store')
  if (req.url === '/stats') { res.setHeader('Content-Type','application/json'); res.end(JSON.stringify({ ...counts, firstPollDelayMs })); return }
  if (!['http://127.0.0.1:4178','http://localhost:4178'].includes(req.headers.origin)) { res.writeHead(403).end(); return }
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin)
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  res.setHeader('Access-Control-Allow-Methods', 'POST')
  if (req.method === 'OPTIONS') { res.writeHead(204).end(); return }
  const chunks = []; for await (const chunk of req) chunks.push(chunk)
  const { action } = JSON.parse(Buffer.concat(chunks).toString())
  let mode = 'success'; try { mode = (await readFile('.cache/schedule-ui-mode.txt', 'utf8')).trim() } catch {}
  if (action in counts) counts[action]++
  res.setHeader('Content-Type', 'application/json')
  if (mode === 'failure' && action === 'start') { res.writeHead(503).end(JSON.stringify({error:'fixture failure'})); return }
  if (action === 'start') {
    startedAt = Date.now(); firstPollDelayMs = undefined
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240"><rect width="240" height="240" fill="white"/><text x="25" y="110" font-size="18">TEST ONLY - NO LOGIN</text></svg>'
    waitingView = {state:'waiting',message:'测试响应，不需要扫码。',qr:'data:image/svg+xml;base64,'+Buffer.from(svg).toString('base64'),expiresAt:Date.now()+(mode === 'expiry' ? 6000 : 180000),sessionToken:'a'.repeat(64)}
    res.end(JSON.stringify(waitingView))
  } else if (action === 'poll') {
    firstPollDelayMs ??= Date.now() - startedAt
    if (mode === 'expiry') res.end(JSON.stringify(waitingView))
    else if (mode === 'server-expiry') res.end(JSON.stringify({state:'expired',message:'测试服务端过期。'}))
    else res.end(JSON.stringify({state:'complete',message:'已读取虚构验收数据。',result:{provider:'wust',schoolYear:'2026-2027',semester:1,lessons,notes:['测试备注']}}))
  }
  else res.end(JSON.stringify({state:'idle',message:'已清除测试会话。'}))
})
server.listen(4259, '127.0.0.1', () => console.log('Schedule QA fixture http://127.0.0.1:4259'))
