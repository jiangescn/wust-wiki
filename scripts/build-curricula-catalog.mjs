// Build the public index from reviewed archive metadata, never from a directory-wide copy.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs'
import { resolve, relative, basename, extname } from 'node:path'
import { createHash } from 'node:crypto'

const root = resolve('docs/curricula')
const publicRoot = resolve('public/files/curricula')
const check = process.argv.includes('--check')
const records = new Map(), assets = new Map()
const digest = value => createHash('sha256').update(value).digest('hex')
const read = path => readFileSync(resolve(root, path), 'utf8').replace(/^\uFEFF/, '')
function csv(text) {
  const rows = []; let row = [], value = '', quoted = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (c === '"') { if (quoted && text[i + 1] === '"') { value += '"'; i++ } else quoted = !quoted }
    else if (c === ',' && !quoted) { row.push(value); value = '' }
    else if (c === '\n' && !quoted) { row.push(value.replace(/\r$/, '')); rows.push(row); row = []; value = '' }
    else value += c
  }
  if (quoted) throw new Error('Unterminated CSV field')
  if (value || row.length) { row.push(value.replace(/\r$/, '')); rows.push(row) }
  const headers = rows.shift()
  return rows.filter(r => r.some(Boolean)).map((r, i) => {
    if (r.length !== headers.length) throw new Error(`CSV row ${i + 2}: expected ${headers.length}, got ${r.length}: ${JSON.stringify(r)}`)
    return Object.fromEntries(headers.map((h, i) => [h, r[i]]))
  })
}
const split = text => (text || '').split(/[;；]/).map(x => x.trim()).filter(Boolean)
function official(url) {
  const parsed = new URL(url)
  if (!['https:', 'http:'].includes(parsed.protocol) || !parsed.hostname.endsWith('.wust.edu.cn')) throw new Error(`Unexpected source: ${url}`)
  return url
}
function file(path) {
  const absolute = resolve(root, path), rel = relative(root, absolute)
  if (rel.startsWith('..') || !['.pdf', '.doc'].includes(extname(path))) throw new Error(`Invalid document: ${path}`)
  const bytes = readFileSync(absolute), hash = digest(bytes), extension = extname(path)
  if (extension === '.pdf' && bytes.subarray(0, 5).toString() !== '%PDF-') throw new Error(`Not PDF: ${path}`)
  if (extension === '.doc' && bytes.subarray(0, 8).toString('hex') !== 'd0cf11e0a1b11ae1') throw new Error(`Not DOC: ${path}`)
  const name = hash.slice(0, 24) + extension, destination = resolve(publicRoot, name)
  if (check) {
    if (!existsSync(destination) || digest(readFileSync(destination)) !== hash) throw new Error(`Missing/changed public document: ${path}`)
  } else { mkdirSync(publicRoot, { recursive: true }); writeFileSync(destination, bytes) }
  assets.set(name, { path, sha256: hash, bytes: bytes.length })
  return { url: `/files/curricula/${name}`, format: extension.slice(1).toUpperCase() }
}
function entry(level, college, program, extra = {}) {
  const id = digest(`${level}/${college}/${program}`).slice(0, 16)
  if (!records.has(id)) records.set(id, { id, level, college, program, status: '', note: '', sources: [], documents: [], ...extra })
  return records.get(id)
}
function add(target, document) {
  if (!target.documents.some(d => d.url === document.url)) target.documents.push({ ...document, sources: [...new Set(document.sources || [])].map(official) })
}
function archiveSources(college, filename) {
  const lines = read(`本科/${college}/README.md`).split('\n').filter(line => line.includes(filename))
  return [...new Set(lines.flatMap(line => [...line.matchAll(/\]\((https?:\/\/[^\s)]+)\)/g)].map(m => official(m[1]))))]
}
const undergraduates = csv(read('本科/专业覆盖总表.csv'))
if (undergraduates.length !== 76 || new Set(undergraduates.map(row => row['学院'])).size !== 22) throw new Error('Review undergraduate baseline before changing coverage')
const indexedFiles = new Set()
for (const row of undergraduates) {
  const sources = split(row['官方来源']).map(official)
  const target = entry('本科', row['学院'], row['专业/项目'], { status: row['公开材料状态'], note: row['核对说明'], sources })
  for (const path of split(row['本地文件'])) {
    const userProvided = path.includes('用户提供')
    if (path.endsWith('.html')) {
      add(target, { title: basename(path, '.html'), version: row['版本'], provenance: '官网正文', url: sources[0], format: '网页', sources, note: row['核对说明'] })
      continue
    }
    indexedFiles.add(path)
    const version = basename(path).match(/20\d{2}(?:级|版)?/)?.[0] || '年级未标'
    add(target, { ...file(`本科/${path}`), title: basename(path, extname(path)), version: userProvided ? `${version}（文件标注）` : version,
      provenance: userProvided ? '用户提供／版本待核' : path.includes('电子信息类') ? '官网图像整理' : '官方原件',
      sources: userProvided ? [] : sources,
      note: userProvided ? '来源与最终版本未认证；DOC 的专业与年级按文件名归类，正文待核。请以最终印发版和系统最终版为准。' : row['核对说明'] })
  }
}

// Additional historical/project entries are kept distinct instead of being mapped to a newer major.
const supplemental = {
  '外国语学院': { '德语专业本科学分制培养方案-来源未标年级.pdf': '德语（历史专业方案）' },
  '资源与环境工程学院': { '2025级-资源智能提取双学士项目-培养方案.pdf': '资源智能提取（双学士项目）' },
  '法学与经济学院': {
    '2018级-投资学-培养方案-官方历史原件.pdf': '投资学（历史专业）',
    '2024级-投资学-培养方案-官网原件.pdf': '投资学（历史专业）',
    '2018级-国际经济与贸易-培养方案-官网原件.pdf': '国际经济与贸易（历史专业）',
  },
  '汽车与交通工程学院': {
    '2024级-机械类车辆与智能车辆-培养方案-官网原件.pdf': '机械类（车辆工程、智能车辆工程）',
    '2024级-车辆工程产业计划-培养方案-官网原件.pdf': '车辆工程（产业计划）',
    '2024级-交通工程-培养方案-官网原件.pdf': '交通工程',
    '2024级-物流工程-培养方案-官网原件.pdf': '物流工程（历史专业）',
  },
}
for (const [college, files] of Object.entries(supplemental)) for (const [filename, program] of Object.entries(files)) {
  const sources = archiveSources(college, filename)
  if (!sources.length) throw new Error(`Missing provenance: ${filename}`)
  add(entry('本科', college, program), { ...file(`本科/${college}/${filename}`), title: filename.replace(/\.pdf$/, ''), version: filename.match(/20\d{2}级/)?.[0] || '年级未标', provenance: '官方原件', sources,
    note: filename.includes('资源智能提取') ? '双学士项目；官网目录写 2024 级，PDF 课程表写 2025 级，中英文总学分也有差异，请向学院确认。' : '历史专业或项目材料，适用范围以原件为准；不视为当前年级普通班方案。' })
}
for (const filename of readdirSync(resolve(root, '本科/化学与化工学院')).filter(f => f.endsWith('.pdf'))) {
  if (indexedFiles.has(`化学与化工学院/${filename}`)) continue
  const program = filename.includes('化工与制药类') ? '化工与制药类（历史大类）' : filename.includes('应用化学') ? '应用化学' : filename.includes('生物工程') ? '生物工程' : '化学工程与工艺'
  const sources = archiveSources('化学与化工学院', filename)
  if (!sources.length) throw new Error(`Missing provenance: ${filename}`)
  add(entry('本科', '化学与化工学院', program), { ...file(`本科/化学与化工学院/${filename}`), title: filename.replace(/\.pdf$/, ''), version: filename.slice(0, 5), provenance: '官方原件', sources, note: '历史版本；大类与产业计划方案不自动适用于普通专业班。' })
}
// Unmapped DOCs are offered under their own filename-based labels, not substituted for current majors.
const userDir = '计算机科学与技术学院/非官方渠道-用户提供/2024级-系统参考稿内DOC原件'
for (const filename of readdirSync(resolve(root, `本科/${userDir}`)).filter(f => f.endsWith('.doc'))) {
  const path = `${userDir}/${filename}`
  if (indexedFiles.has(path)) continue
  const program = filename.match(/2024(.+?)培养方案/)?.[1]
  if (!program) throw new Error(`Unmapped DOC: ${filename}`)
  add(entry('本科', '计算机科学与技术学院', `${program}（参考稿）`), { ...file(`本科/${path}`), title: filename.replace(/\.doc$/, ''), version: '2024（文件名）', provenance: '用户提供／版本待核', sources: [], note: '专业与年级仅按文件名记录，正文待核；信息安全不映射为网络空间安全，专项计划不替代普通班。' })
}

const graduate = JSON.parse(read('研究生/manifest.json'))
for (const item of graduate.results) {
  const programs = item.schemeHeadings.length ? item.schemeHeadings : ['学院汇编（专业目录待核）']
  for (const program of programs) {
    const target = entry('研究生', item.college, program, { status: item.status, note: item.inspection, sources: [official(item.page)] })
    for (const doc of item.files) add(target, { ...file(`研究生/${item.college}/${doc.filename}`), title: item.title, version: `${item.year}版`, provenance: '官方原件', sources: [item.page, doc.url], note: item.schemeHeadings.length > 1 ? '学院合集，包含本方案；请在 PDF 中查找对应标题。' : item.inspection })
    if (item.status === '仅网页正文') add(target, { title: item.title, version: `${item.year}版`, provenance: '官网正文', url: official(item.page), format: '网页', sources: [item.page], note: item.inspection })
    if (item.status === '附件需验证码') target.note = '官网附件需要验证码，请前往学校原页获取；尚未核对附件正文。'
  }
}
const collectionSource = 'https://fxyjj.wust.edu.cn/__local/4/A7/86/053314CC198B70BB87E80ECA7F1_ECA3C244_25D7C2.pdf'
for (const row of csv(read('研究生/校方合编摘录索引.csv'))) {
  const colleges = [row['归档学院'], ...split(row['关联学院（目录组含/相关）'])]
  for (const college of new Set(colleges.filter(Boolean))) add(entry('研究生', college, row['正文首页标题']), {
    ...file(`研究生/${row['本地摘录路径']}`), title: row['正文首页标题'], version: '版本待核', provenance: '校方合编摘录／版本待核', sources: [collectionSource],
    note: `原合集 PDF 第 ${row['原PDF页起']}–${row['原PDF页止']} 页。${row['核验备注']}不作为统一 2025 版。`,
  })
}

for (const [filename, source] of [
  ['哲学学术学位硕士研究生培养方案-校方域名直链-版本待核.pdf', 'https://jxjyxy.wust.edu.cn/__local/E/10/13/84B3312563E502564022BC1CC2C_E6633635_3CF29.pdf'],
  ['马克思主义理论学术学位硕士研究生培养方案-校方域名副本-版本待核.pdf', 'https://jxjyxy.wust.edu.cn/__local/A/31/E2/EA8006561A2095F55B8A8231BFD_A3B44431_38498.pdf'],
]) add(entry('研究生', '马克思主义学院', filename.split('-')[0]), {
  ...file(`研究生/马克思主义学院/${filename}`), title: filename.replace(/\.pdf$/, ''), version: '版本待核', provenance: '校方域名副本／版本待核', sources: [source],
  note: '正文未标年级，原始发布页未定位；未证实与 2025 年验证码附件同版。',
})

for (const item of records.values()) item.documents.sort((a, b) => Number(b.version.match(/20\d{2}/)?.[0] || 0) - Number(a.version.match(/20\d{2}/)?.[0] || 0))
const catalog = { checked: graduate.checked, records: [...records.values()] }
const userDocuments = new Set(catalog.records.flatMap(r => r.documents.filter(d => d.provenance === '用户提供／版本待核').map(d => d.url)))
if (userDocuments.size !== 13) throw new Error('Review user-provided file coverage')
for (const record of catalog.records) for (const doc of record.documents) {
  if (doc.provenance !== '用户提供／版本待核' && !doc.sources.length) throw new Error(`Missing official provenance: ${doc.title}`)
  if (doc.format === '网页' && !doc.url) throw new Error(`Missing page URL: ${doc.title}`)
}
const output = 'app/data/curricula.json', manifest = 'docs/curricula-public-manifest.json'
for (const [path, data] of [[output, catalog], [manifest, Object.fromEntries(assets)]]) {
  const json = JSON.stringify(data, null, 2) + '\n'
  if (check) { if (readFileSync(path, 'utf8') !== json) throw new Error(`Stale catalog: ${path}`) }
  else writeFileSync(path, json)
}
console.log(`Curricula ${check ? 'verified' : 'built'}: ${records.size} program entries, ${assets.size} documents, ${(Array.from(assets.values()).reduce((n, a) => n + a.bytes, 0) / 1024 / 1024).toFixed(1)} MiB`)
