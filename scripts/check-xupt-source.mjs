import { readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import assert from 'node:assert/strict'

const manifest = JSON.parse(readFileSync('vendor/xupt-wiki/migration-manifest.json', 'utf8'))
const hash = value => createHash('sha256').update(value).digest('hex')
const styles = value => [...value.matchAll(/<style\b[^>]*>[\s\S]*?<\/style>/g)].map(match => match[0])
for (const entry of manifest.components) {
  const source = readFileSync(entry.original)
  const runtime = readFileSync(entry.runtime)
  assert.equal(hash(source), entry.sourceSha256, `Source snapshot changed: ${entry.original}`)
  assert.equal(hash(runtime), entry.runtimeSha256, `Update migration record after reviewing: ${entry.runtime}`)
  assert.deepEqual(styles(runtime.toString()), styles(source.toString()), `Original styles/animations changed: ${entry.runtime}`)
}
console.log(`XUPT source OK: ${manifest.components.length} components, original styles/animations preserved.`)
