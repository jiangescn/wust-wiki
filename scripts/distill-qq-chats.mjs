import fs from 'node:fs'
import path from 'node:path'

const exportRoot = process.argv[2]
const outputFile = process.argv[3]

if (!exportRoot || !outputFile) {
  console.error('Usage: node scripts/distill-qq-chats.mjs <export-root> <output-json>')
  process.exit(1)
}

const topics = {
  accommodation: /宿舍|寝室|南[一二三四五六七八九十\d]+|北[一二三四五六七八九十\d]+|空调|洗澡|浴室|热水|门禁|床|上床下桌|独卫|洗衣机|电费|水费|宿管|断电/,
  enrollment: /报到|入学|新生|军训|体检|户口|团组织|档案|迎新|缴费|绿色通道|行李|校历/,
  network_apps: /校园网|宽带|锐捷|WiFi|wifi|WIFI|企业微信|今日校园|学习通|教务|课表|一卡通|校园卡|完美校园|i武科大|掌上武科大/,
  study: /选课|抢课|补考|重修|挂科|绩点|GPA|综测|保研|转专业|四六级|四级|六级|考试|成绩|学分|奖学金|教务处/,
  delivery: /快递|驿站|菜鸟|外卖|收货地址|取件|寄件|跑腿/,
  food: /食堂|南院|北园|北苑|沁湖|餐厅|窗口|热干面|早餐|夜宵|饭卡/,
  transport: /地铁|公交|校车|打车|火车站|武汉站|武昌站|汉口站|机场|共享单车|青山校区|黄家湖校区|洪山校区/,
  facilities: /图书馆|打印|复印|医务室|医院|超市|澡堂|体育馆|操场|自习室|空教室|失物招领/,
  safety: /诈骗|骗子|兼职|刷单|校园贷|推销|盗窃|防骗|代课|代写|代考/,
  organizations: /社团|学生会|青协|招新|实验室|ACM|竞赛|创新创业|大创|志愿时长/,
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'))
}

function readJsonl(file) {
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line))
}

function sanitize(text) {
  return text
    .replace(/\[图片:[^\]]+\]/g, '')
    .replace(/\[回复[^:\]]*:/g, '[回复用户:')
    .replace(/@[\p{L}\p{N}_（）()·.\-]+/gu, '@用户')
    .replace(/(?<!\d)1[3-9]\d{9}(?!\d)/g, '[手机号已隐藏]')
    .replace(/(QQ|qq|群号|Q群|裙号|群)[：:\s]*\d{6,12}/g, '$1[号码已隐藏]')
    .replace(/(微信|vx|V|v)[：:\s]*[a-zA-Z][\w-]{5,19}/g, '$1[账号已隐藏]')
    .replace(/\s+/g, ' ')
    .trim()
}

const sources = []
for (const entry of fs.readdirSync(exportRoot, { withFileTypes: true })) {
  const fullPath = path.join(exportRoot, entry.name)
  if (entry.isFile() && entry.name.endsWith('.json')) {
    const data = readJson(fullPath)
    sources.push({ name: data.chatInfo?.name ?? entry.name, messages: data.messages ?? [], statistics: data.statistics })
  } else if (entry.isDirectory()) {
    const manifestPath = path.join(fullPath, 'manifest.json')
    const chunksPath = path.join(fullPath, 'chunks')
    if (!fs.existsSync(manifestPath) || !fs.existsSync(chunksPath)) continue
    const manifest = readJson(manifestPath)
    const messages = fs.readdirSync(chunksPath)
      .filter(name => name.endsWith('.jsonl'))
      .sort()
      .flatMap(name => readJsonl(path.join(chunksPath, name)))
    sources.push({ name: manifest.chatInfo?.name ?? entry.name, messages, statistics: manifest.statistics })
  }
}

const summary = []
const candidates = Object.fromEntries(Object.keys(topics).map(topic => [topic, []]))

for (const source of sources) {
  const seen = new Set()
  const unique = []
  for (const message of source.messages) {
    const key = String(message.id ?? `${message.timestamp}:${message.content?.text}`)
    if (seen.has(key)) continue
    seen.add(key)
    const text = sanitize(String(message.content?.text ?? ''))
    if (!text || message.system || message.type === 'forward' || text.length < 2 || text.length > 500) continue
    unique.push({ id: key, timestamp: message.timestamp, time: message.time, text })
  }

  summary.push({
    name: source.name,
    exportedMessages: source.messages.length,
    uniqueTextMessages: unique.length,
    timeRange: source.statistics?.timeRange,
  })

  for (let index = 0; index < unique.length; index += 1) {
    const message = unique[index]
    for (const [topic, pattern] of Object.entries(topics)) {
      if (!pattern.test(message.text)) continue
      const context = unique.slice(Math.max(0, index - 2), Math.min(unique.length, index + 3))
        .filter(item => Math.abs(Number(item.timestamp) - Number(message.timestamp)) <= 10 * 60 * 1000)
        .map(item => ({ time: item.time, text: sanitize(item.text) }))
      candidates[topic].push({ source: source.name, time: message.time, text: message.text, context })
    }
  }
}

fs.mkdirSync(path.dirname(outputFile), { recursive: true })
fs.writeFileSync(outputFile, JSON.stringify({ generatedAt: new Date().toISOString(), summary, candidates }, null, 2))
console.log(JSON.stringify({ summary, topicCounts: Object.fromEntries(Object.entries(candidates).map(([key, value]) => [key, value.length])) }, null, 2))
