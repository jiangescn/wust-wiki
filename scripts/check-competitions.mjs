import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'

const rows = JSON.parse(await readFile('app/data/competitions-2024.json', 'utf8'))
assert.deepEqual(rows.map(item => item.id), Array.from({ length: 253 }, (_, index) => index + 1))
const counts = Object.fromEntries(['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map(level => [level, rows.filter(item => item.level === level).length]))
assert.deepEqual(counts, { A1: 3, A2: 17, B1: 88, B2: 65, C1: 61, C2: 19 })
const pageEnds = [12, 25, 37, 49, 61, 73, 86, 100, 114, 128, 141, 153, 166, 180, 193, 206, 219, 232, 246, 253]
for (const item of rows) {
  assert.equal(item.pdfPage, 8 + pageEnds.findIndex(end => item.id <= end))
  assert.equal(item.printedPage, item.pdfPage + 1)
  assert.ok(item.name && item.host && item.organizers.length && item.organizers.every(Boolean), `incomplete row ${item.id}`)
  assert.equal(typeof item.ranked, 'boolean')
  if (item.id >= 109) assert.equal(item.audience, null)
  else assert.ok(['本科生', '研究生', '全校学生'].includes(item.audience))
}
assert.equal(rows[35].level, 'B1')
assert.equal(rows[135].level, 'B2')
assert.equal(rows[44].level, 'B1')
assert.equal(rows[149].level, 'B2')
assert.notEqual(rows[203].host, rows[205].host)
assert.equal(rows[177].name, '全国大学生电化学测量技术')
assert.equal(createHash('sha256').update(await readFile('public/files/competition-catalog-2024.pdf')).digest('hex'), '15aad60fab950635ede78f78cc0a9c4eaa3ed71e601d964ae7f9c3ac5a4054e8')
console.log('Competition source OK: 253 rows, six categories, 27-page source hash, page mapping and unknown audiences preserved.')
