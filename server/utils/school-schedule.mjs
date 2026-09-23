import { parse, parseFragment, serialize } from 'parse5'

// Observed in the authenticated xsMain.jsp iframe, not a guessed API.
const timetableUrl = 'https://bkjx.wust.edu.cn/jsxsd/xskb/xskb_list.do'
const attrs = node => Object.fromEntries((node.attrs || []).map(a => [a.name, a.value]))
const nodes = tree => [tree, ...(tree.childNodes || []).flatMap(nodes)]
const plain = node => node.nodeName === '#text' ? node.value : node.tagName === 'br' ? '\n' : ['script', 'style'].includes(node.tagName) ? '' : (node.childNodes || []).map(plain).join('')
const clean = value => value.replace(/[\t\r ]+/g, ' ').trim()
const hasClass = (node, name) => (attrs(node).class || '').split(/\s+/).includes(name)

export function parseSchoolSchedule(html) {
  const all = nodes(parse(html))
  const table = all.find(n => n.tagName === 'table' && attrs(n).id === 'kbtable')
  if (!table || !/星期一/.test(plain(table)) || !/星期日/.test(plain(table))) return null
  const lessons = []
  const notes = []
  let timetableRows = 0
  for (const row of nodes(table).filter(n => n.tagName === 'tr')) {
    const cells = (row.childNodes || []).filter(n => ['td', 'th'].includes(n.tagName))
    if (/^备注\s*[:：]/.test(clean(plain(cells[0] || {})))) {
      notes.push(...cells.slice(1).flatMap(c => plain(c).split('\n').map(clean).filter(Boolean)))
      continue
    }
    if (!/\d+.*小节/.test(plain(cells[0] || {}))) continue
    if (cells.length !== 8) return null
    timetableRows++
    for (let day = 1; day <= 7; day++) {
      // Ignore kbcontent1 (the compact duplicate); retain separate lab entries.
      for (const content of nodes(cells[day]).filter(n => hasClass(n, 'kbcontent'))) {
        for (const part of serialize(content).split(/-{5,}/)) {
          const fragment = parseFragment(part)
          const lines = plain(fragment).split('\n').map(clean).filter(Boolean)
          if (!lines.length) continue
          const fields = nodes(fragment)
          const field = title => clean(plain(fields.find(n => attrs(n).title === title) || {}))
          const time = field('周次(节次)')
          const match = time.match(/^(.+?)\s*[（(]周[）)]\s*\[([^\]]+)节\]$/)
          if (!match || !/^\d+(?:\s*[-,，]\s*\d+)*$/.test(match[2])) return null
          const sections = match[2].match(/\d+/g).map(Number)
          if (sections.some(n => n < 1 || n > 30)) return null
          lessons.push({ name: lines[0], teacher: field('老师'), location: field('教室'), day,
            start: sections[0], end: sections.at(-1), sections: match[2], weeks: match[1],
            group: lines.slice(1).filter(line => /^[(（]分组/.test(line)).join(' '),
          })
        }
      }
    }
  }
  if (!timetableRows) return null
  const termSelect = all.find(n => n.tagName === 'select' && attrs(n).id === 'xnxq01id')
  const options = nodes(termSelect || {}).filter(n => n.tagName === 'option')
  const selected = options.find(n => Object.hasOwn(attrs(n), 'selected')) || options[0]
  const term = selected ? attrs(selected).value : ''
  const termMatch = /^(\d{4}-\d{4})-([12])$/.exec(term || '')
  return { provider: 'wust', ...(termMatch ? { schoolYear: termMatch[1], semester: Number(termMatch[2]) } : {}), lessons, notes }
}

export async function readSchoolSchedule(client) {
  const response = await client.request(timetableUrl)
  const html = response.bytes.toString('utf8')
  if (new URL(response.url).origin !== 'https://bkjx.wust.edu.cn' || /lyuapServer\/login|<title[^>]*>\s*登录/.test(html)) {
    return { state: 'needs_action', message: '教务系统仍要求登录，未读取课表。请在官方入口检查认证状态。' }
  }
  const result = parseSchoolSchedule(html)
  if (!result) return { state: 'needs_adapter', message: '教务页面格式与已验证的课表结构不一致，未将其当作空课表。临时认证材料已清除。' }
  return { state: 'complete', message: '已获取学校当前学期课表，服务端登录会话已清除。', result }
}
