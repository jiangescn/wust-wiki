import fs from 'node:fs'

const [file, topic, patternText, limitText = '80'] = process.argv.slice(2)
if (!file || !topic || !patternText) {
  console.error('Usage: node scripts/query-chat-distillation.mjs <file> <topic> <regex> [limit]')
  process.exit(1)
}

const data = JSON.parse(fs.readFileSync(file, 'utf8'))
const pattern = new RegExp(patternText, 'i')
const limit = Number(limitText)
const seen = new Set()
let shown = 0

for (const item of data.candidates[topic] ?? []) {
  if (!pattern.test(item.text)) continue
  const normalized = item.text.replace(/\[回复[^\]]*\]/g, '').replace(/@[\p{L}\p{N}_（）()·.\-]+/gu, '@用户').trim()
  if (seen.has(normalized)) continue
  seen.add(normalized)
  console.log(`\n[${item.source} | ${item.time}] ${normalized}`)
  for (const context of item.context) console.log(`  ${context.time}: ${context.text}`)
  shown += 1
  if (shown >= limit) break
}

console.error(`shown=${shown}`)
