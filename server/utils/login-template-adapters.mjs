import { createUpstreamClient, form, jsonPost, inputValue, pngData } from './login-template-http.mjs'
import { readSchoolSchedule } from './school-schedule.mjs'
import { readSchoolGrades } from './school-grades.mjs'

const passport = 'https://passport2.chaoxing.com'
const kb = 'https://kb.chaoxing.com'
const auth = 'https://auth.wust.edu.cn'
const teaching = 'https://bkjx.wust.edu.cn/jsxsd/'
const helper = 'https://lyzyy.love:8081'
const helperPath = helper + '/UnderGraduate/Support/'
const uuidPattern = /^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i
const text = v => typeof v === 'string' ? v.slice(0, 300) : ''
const number = v => Number.isFinite(Number(v)) ? Number(v) : undefined
const ok = result => [0, 200, 10000, 11000].includes(result?.code)

export const templateProviders = [
  { id: 'chaoxing', title: '学习通扫码', scanner: '学习通 App', description: '扫码后获取当前课表 UUID 和本周课程。', boundary: '遇到二次验证或登录态未传递时停止，转到官方页面完成。', officialUrl: passport + '/login?refer=' + encodeURIComponent(kb + '/res/pc/curriculum/schedule.html') },
  { id: 'wust', title: '学校微信扫码', scanner: '微信', description: '扫码后读取学校当前学期课表。', boundary: '直接连接学校认证与教务系统，读取全学期排课和课表备注。', officialUrl: teaching },
  { id: 'helper', title: '武科大助手扫码', scanner: '微信', description: '参考助手客户端的扫码接口，尝试读取本科课表。', boundary: '这是第三方助手服务器；遇到绑定或二次验证时停止。', officialUrl: teaching },
]

export function createLoginAdapter(provider, fetchImpl = fetch, { authenticateOnly = false, readGrades = readSchoolGrades } = {}) {
  const origins = provider === 'chaoxing' ? [passport, kb] : provider === 'wust' ? [auth, 'https://bkjx.wust.edu.cn'] : provider === 'helper' ? [helper] : []
  if (!origins.length) throw new Error('UNKNOWN_PROVIDER')
  const client = createUpstreamClient(origins, fetchImpl)
  let secret = {}
  const close = () => { secret = {}; client.close() }
  const stop = (message, state = 'needs_action') => ({ state, message })
  return {
    close,
    async read(resource) {
      if (provider !== 'wust' || !authenticateOnly) throw new Error('INVALID_RESOURCE')
      if (resource === 'schedule') return readSchoolSchedule(client)
      if (resource === 'grades') return readGrades(client)
      throw new Error('INVALID_RESOURCE')
    },
    async start() {
      if (provider === 'chaoxing') {
        const html = await client.text(templateProviders[0].officialUrl)
        secret = { uuid: inputValue(html, 'uuid'), enc: inputValue(html, 'enc'), doubleFactorLogin: inputValue(html, 'doubleFactorLogin'), forbidotherlogin: inputValue(html, 'forbidotherlogin') }
        if (!/^[a-f\d]{20,64}$/i.test(secret.uuid) || !secret.enc) throw new Error('LOGIN_PAGE_CHANGED')
        const image = await client.request(passport + '/createqr?uuid=' + encodeURIComponent(secret.uuid) + '&fid=-1')
        return { state: 'waiting', qr: pngData('data:image/png;base64,' + image.bytes.toString('base64')), message: '请用学习通 App 扫码，并核对手机上的登录提示。', lifetime: 150_000 }
      }
      if (provider === 'wust') {
        await client.text(auth + '/lyuapServer/login?service=' + encodeURIComponent(teaching))
        const data = await client.json(auth + '/lyuapServer/weChat/CreateQRcode?businessType=login&platformType=wx')
        if (typeof data.uuid !== 'string' || data.uuid.length > 256) throw new Error('LOGIN_PAGE_CHANGED')
        secret = { state: data.uuid }
        return { state: 'waiting', qr: pngData(data.content), message: '请用已绑定学校身份的微信扫码，核对手机上的登录提示。', lifetime: 180_000 }
      }
      const result = await client.json(helperPath + 'wechatLogin/start', jsonPost({}))
      if (!ok(result) || typeof result.data?.state !== 'string' || result.data.state.length > 512) throw new Error('LOGIN_PAGE_CHANGED')
      secret = { state: result.data.state }
      return { state: 'waiting', qr: pngData(result.data.qr_code), message: '此二维码由武科大助手服务器提供，请用微信扫码。', lifetime: 180_000 }
    },
    async poll() {
      if (provider === 'chaoxing') {
        const status = await client.json(passport + '/getauthstatus/v2', form(secret))
        if (status.status === true || status.status === 1) {
          if (status.containTwoFactorLogin) return stop('学习通要求二次验证。请到官方页面完成，本模板已清除临时会话。')
          await client.text(kb + '/res/pc/curriculum/schedule.html')
          const result = await client.json(kb + '/pc/curriculum/getMyLessons')
          const c = result.data?.curriculum
          if (result.result !== 1 || !uuidPattern.test(c?.uuid || '') || !Array.isArray(result.data?.lessonArray)) return stop('扫码已确认，但未取得课表。可能需要补充认证、切换单位或已有会话未传递。')
          return { state: 'complete', message: '已获取课表 UUID 和本周课程，服务端登录会话已清除。', result: {
            provider, curriculumUuid: c.uuid, schoolYear: text(c.schoolYear), semester: number(c.semester), currentWeek: number(c.currentWeek), maxWeek: number(c.maxWeek),
            lessons: result.data.lessonArray.slice(0, 1000).map(l => ({ name: text(l.name || l.displayCourseName), teacher: text(l.teacherName), location: text(l.location), day: number(l.dayOfWeek), start: number(l.beginNumber), length: number(l.length), weeks: Array.isArray(l.weeks) ? l.weeks.map(number).filter(v => v !== undefined).slice(0, 60).join(',') : text(l.weeks) })),
          } }
        }
        if ([6, 7].includes(Number(status.type))) return stop('学习通登录已取消或二维码失效，请重新生成。', 'cancelled')
        return { state: Number(status.type) === 4 ? 'scanned' : 'waiting', message: Number(status.type) === 4 ? '已扫码，请在学习通 App 中确认登录。' : '等待学习通扫码。' }
      }
      if (provider === 'wust') {
        const pollOptions = jsonPost({ state: secret.state })
        delete pollOptions.headers.Platform
        pollOptions.headers['X-Requested-With'] = 'XMLHttpRequest'
        const status = await client.json(auth + '/lyuapServer/weChat/wx/CheckScan', pollOptions)
        if (!status.meta?.success || !status.data) return { state: 'waiting', message: '等待微信扫码确认；二维码最多保留三分钟。' }
        const data = status.data
        if (!data?.userName || !data?.passWord) return stop('学校认证需要绑定身份或额外验证。请到官方页面完成。')
        // passWord is an opaque field supplied by the official QR flow, never user input.
        const ticketOptions = form({ username: data.userName, password: data.passWord, service: teaching, loginType: '3' })
        ticketOptions.headers['X-Requested-With'] = 'XMLHttpRequest'
        const ticket = await client.json(auth + '/lyuapServer/v1/tickets', ticketOptions)
        if (typeof ticket.ticket !== 'string' || !ticket.ticket || ticket.ticket.length > 2048) return stop('扫码已确认，但未取得教务系统票据。请到官方页面检查绑定或认证要求。')
        const response = await client.request(teaching + '?ticket=' + encodeURIComponent(ticket.ticket))
        const html = response.bytes.toString('utf8')
        if (/lyuapServer\/login|<title[^>]*>\s*登录/.test(html)) return stop('学校扫码认证已响应，但教务系统仍要求登录，需继续核对票据交换。')
        secret = {}
        return authenticateOnly ? { state: 'authenticated', message: '' } : await readSchoolSchedule(client)
      }
      const status = await client.json(helperPath + 'wechatLogin/status', jsonPost({ state: secret.state }))
      if (ok(status) && status.data?.status === 'pending') return { state: 'waiting', message: '等待微信扫码确认。' }
      if (status.data?.status === 'two_verify') return stop('助手要求二次验证。请回助手完成，本模板不发送短信。')
      const token = status.data?.token
      if (!ok(status) || typeof token !== 'string' || !token || token.length > 16000) return stop('助手未返回有效登录会话，可能已过期或需绑定身份。')
      const result = await client.json(helperPath + 'getCoursesPage', { headers: { Authorization: 'Bearer ' + token, Platform: 'android' } })
      if (!ok(result) || !Array.isArray(result.data)) return stop('助手登录有响应，但课表格式与参考客户端不一致，需进一步适配。')
      return { state: 'complete', message: '已获取助手返回的本科课表，服务端登录令牌已清除。', result: { provider,
        lessons: result.data.slice(0, 1000).map(l => ({ name: text(l.className || l.courseName || l.name), teacher: text(l.teacher), location: text(l.classroom), day: number(l.weekDay ?? l.weekday ?? l.dayOfWeek), start: number(l.section ?? l.startSection ?? l.start_section), end: number(l.endSection ?? l.end_section ?? l.sectionEnd), weeks: [number(l.startWeek ?? l.start_week), number(l.endWeek ?? l.end_week)].filter(v => v !== undefined).join('–') })),
      } }
    },
  }
}
