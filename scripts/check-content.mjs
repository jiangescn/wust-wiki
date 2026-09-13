import { readdir, readFile, stat } from 'node:fs/promises'
import { join, relative, sep } from 'node:path'
import { homeEntries, wikiNavigation } from '../app/data/wiki.ts'

async function files(dir) {
  const entries = await readdir(dir, { withFileTypes: true })
  return (await Promise.all(entries.map(entry => entry.isDirectory() ? files(join(dir, entry.name)) : join(dir, entry.name)))).flat()
}
const pages = (await files('content')).filter(file => file.endsWith('.md') && file !== join('content', 'index.md'))
const routes = new Set(['/', '/articles'])
const documents = []
for (const file of pages) {
  const route = '/' + relative('content', file).split(sep).map(part => part.replace(/^\d+\./, '')).join('/').replace(/\.md$/, '').replace(/(?:^|\/)index$/, '')
  if (routes.has(route)) throw new Error(`Duplicate route: ${route}`)
  routes.add(route)
  const text = await readFile(file, 'utf8')
  if (!/^title: .+$/m.test(text) || !/^status: (draft|published)$/m.test(text)) throw new Error(`Missing title/status: ${file}`)
  const updated = text.match(/^updated: ['"]?(\d{4}-\d{2}-\d{2})['"]?$/m)?.[1]
  if (/^updated:/m.test(text) && (!updated || Number.isNaN(Date.parse(updated)))) throw new Error(`Invalid updated date: ${file}`)
  documents.push({ file, text })
}
const links = [...homeEntries.map(entry => [entry.to, 'home']), ...wikiNavigation.flatMap(group => group.children.map(entry => [entry.to, group.label]))]
for (const { file, text } of documents) {
  for (const match of text.matchAll(/(?:\]\(|(?:link|to)=['"])(\/[^\s)'"}]+)/g)) links.push([match[1], file])
}
for (const [link, source] of links) {
  const path = link.split(/[?#]/)[0].replace(/\/$/, '') || '/'
  const asset = !path.includes('..') && await stat(join('public', path.slice(1))).then(info => info.isFile()).catch(() => false)
  if (!routes.has(path) && !asset) throw new Error(`Broken internal link: ${link} in ${source}`)
}
console.log(`Content OK: ${pages.length} documents, ${homeEntries.length} homepage entries, ${links.length} internal links.`)
