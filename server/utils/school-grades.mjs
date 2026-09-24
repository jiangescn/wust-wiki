import { parse } from 'parse5'

// Observed in the authenticated cjcx_frm -> cjcx_list iframe on 2026-09-24.
const gradeUrl = 'https://bkjx.wust.edu.cn/jsxsd/kscj/cjcx_list'
const nodes = n => [n, ...(n.childNodes || []).flatMap(nodes)]
const plain = n => n.nodeName === '#text' ? n.value : ['script', 'style'].includes(n.tagName) ? '' : (n.childNodes || []).map(plain).join(' ')
const clean = n => plain(n).replace(/\s+/g, ' ').trim()
const fields = { term: ['开课学期', '学年学期', '学期'], code: ['课程编号', '课程代码'], name: ['课程名称'], score: ['成绩', '总评成绩', '课程成绩'], credit: ['学分'], point: ['绩点', '课程绩点'], nature: ['课程属性', '课程性质'], assessment: ['考核方式'], attempt: ['考试性质', '考试类型'], mark: ['成绩标识', '备注'], group: ['分组名'], makeupTerm: ['补重学期'] }

export function parseSchoolGrades(html) {
  const all = nodes(parse(html))
  for (const table of all.filter(n => n.tagName === 'table')) {
    const rows = nodes(table).filter(n => n.tagName === 'tr')
    const cells = row => (row.childNodes || []).filter(n => ['td', 'th'].includes(n.tagName))
    const headerIndex = rows.findIndex(row => { const labels = cells(row).map(clean); return labels.includes('课程名称') && fields.score.some(s => labels.includes(s)) })
    if (headerIndex < 0) continue
    const headers = cells(rows[headerIndex]).map(clean)
    const indices = Object.fromEntries(Object.entries(fields).map(([field, labels]) => [field, headers.findIndex(h => labels.includes(h))]))
    const courses = []
    for (const row of rows.slice(headerIndex + 1)) {
      const values = cells(row).map(clean)
      if (!values.length || values.every(v => !v)) continue
      if (values.length !== headers.length) {
        if (values.length === 1 && /暂无|无数据|没有.*记录|未查询到/.test(values[0])) continue
        return null
      }
      const course = Object.fromEntries(Object.entries(indices).map(([field, i]) => [field, i < 0 ? '' : values[i].slice(0, 300)]))
      if (!course.name) return null
      courses.push(course)
    }
    if (courses.length > 2000) return null
    return { provider: 'wust', courses }
  }
  return null
}

export async function readSchoolGrades(client) {
  const response = await client.request(gradeUrl)
  const html = response.bytes.toString('utf8')
  if (new URL(response.url).origin !== new URL(gradeUrl).origin || /lyuapServer\/login|<title[^>]*>\s*登录/.test(html)) return { state: 'needs_action', message: '学校登录已失效，请重新扫码。' }
  const result = parseSchoolGrades(html)
  if (!result) return { state: 'needs_adapter', message: '成绩页面格式暂未适配，未将其当作空成绩。请使用教务系统查询。' }
  return { state: 'complete', message: '', result }
}
