import test from 'node:test'
import assert from 'node:assert/strict'
import { createLoginAdapter } from '../server/utils/login-template-adapters.mjs'
import { parseSchoolSchedule, readSchoolSchedule } from '../server/utils/school-schedule.mjs'

// Synthetic courses following the observed school DOM; no personal timetable fixture.
const course = (name, time, teacher = '') => `${name}<br>(分组01)<br><font title="老师">${teacher}</font><br><font title="课堂名称">测试教学班</font><br><font title="周次(节次)">${time}</font><br><font title="教室">测试教室</font><br>`
const fixture = (content = '', note = '') => `<select id="xnxq01id"><option value="2027-2028-1">other</option><option selected value="2026-2027-1">current</option></select><table id="kbtable"><tr><th></th>${['一','二','三','四','五','六','日'].map(v=>`<th>星期${v}</th>`).join('')}</tr><tr><th>11-12小节</th><td><div class="kbcontent1">hidden duplicate</div><div class="kbcontent">${content}</div><div class="kbcontent sykb2"></div></td>${'<td><div class="kbcontent"></div></td>'.repeat(6)}</tr><tr><th>备注:</th><td colspan="7">${note}</td></tr></table>`

test('school QR login exchanges ticket then uses the same teaching session to read the real timetable endpoint', async () => {
  const requests = []
  const adapter = createLoginAdapter('wust', async (url, options) => {
    requests.push(url)
    if (url.endsWith('/CheckScan')) return Response.json({ meta: { success: true }, data: { userName: 'fixture-user', passWord: 'fixture-secret' } })
    if (url.endsWith('/tickets')) return Response.json({ ticket: 'fixture-ticket' })
    if (url.includes('?ticket=')) return new Response('<iframe src="/jsxsd/framework/xsMain_new.jsp"></iframe>', { headers: { 'Set-Cookie': 'JSESSIONID=fixture-session; Path=/jsxsd/; Secure; HttpOnly' } })
    if (url.endsWith('/xskb/xskb_list.do')) {
      assert.match(options.headers.get('cookie'), /JSESSIONID=fixture-session/)
      return new Response(fixture(course('测试课程', '2,4-5(周)[12节]')))
    }
    throw new Error('Unexpected request')
  })
  try {
    const result = await adapter.poll()
    assert.ok(requests.includes('https://bkjx.wust.edu.cn/jsxsd/xskb/xskb_list.do'))
    assert.equal(result.state, 'complete')
    assert.equal(result.result.lessons[0].name, '测试课程')
    assert.doesNotMatch(JSON.stringify(result), /fixture-user|fixture-secret|fixture-ticket|fixture-session/)
  } finally { adapter.close() }
})

test('parses multiple courses, sparse weeks, single sections, missing teachers and unallocated remarks without duplicates', () => {
  const result = parseSchoolSchedule(fixture(course('课程甲 &amp; 乙', '2,4-5(周)[12节]') + '---------------------<br>' + course('课程丙', '1-15单(周)[11-12节]', '测试教师'), '实践课程&nbsp;&nbsp;测试教学班<br>另一门实践课<br>'))
  assert.equal(result.schoolYear, '2026-2027')
  assert.equal(result.semester, 1)
  assert.equal(result.lessons.length, 2)
  assert.deepEqual(result.lessons[0], { name: '课程甲 & 乙', teacher: '', location: '测试教室', day: 1, start: 12, end: 12, sections: '12', weeks: '2,4-5', group: '(分组01)' })
  assert.equal(result.lessons[1].weeks, '1-15单')
  assert.equal(result.notes.length, 2)
})

test('distinguishes a recognized empty timetable from login or changed/unparseable HTML', () => {
  assert.equal(parseSchoolSchedule(fixture()).lessons.length, 0)
  assert.equal(parseSchoolSchedule('<html>登录</html>'), null)
  assert.equal(parseSchoolSchedule(fixture('format changed')), null)
  assert.equal(parseSchoolSchedule(fixture(course('test', 'unknown time'))), null)
})

test('redirect back to official authentication is not treated as an empty timetable', async () => {
  const result = await readSchoolSchedule({ request: async () => ({ url: 'https://auth.wust.edu.cn/lyuapServer/login', bytes: Buffer.from('<html>login</html>') }) })
  assert.equal(result.state, 'needs_action')
  assert.equal(result.result, undefined)
})
