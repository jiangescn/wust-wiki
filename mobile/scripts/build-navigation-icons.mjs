import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = new URL('../../', import.meta.url)
const nativeData = new URL('mobile/assets/native.json', root)
const categoryIcons = {
  study: 'book-open',
  campus: 'building-2',
  future: 'graduation-cap',
  'wiki-life': 'map-pin',
}

export function buildNavigationIcons(navigation) {
  const { icons, aliases, width, height } = JSON.parse(readFileSync(
    new URL('node_modules/.pnpm/node_modules/@iconify-json/lucide/icons.json', root),
    'utf8',
  ))
  const names = new Set(navigation.flatMap(group => [
    categoryIcons[group.id] ?? group.icon ?? 'compass',
    ...group.links.map(link => link.icon ?? 'compass'),
  ]).map(icon => icon.replace(/^lucide:/, '')))
  const assets = Object.fromEntries(Array.from(names).sort().map(name => {
    const icon = icons[name] ?? icons[aliases[name]?.parent]
    if (!icon) throw new Error(`Missing Lucide icon ${name}`)
    return [
      name,
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${icon.width ?? width} ${icon.height ?? height}">${icon.body}</svg>`,
    ]
  }))
  return { categoryIcons, assets }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const data = JSON.parse(readFileSync(nativeData, 'utf8'))
  data.navigationIcons = buildNavigationIcons(data.navigation)
  writeFileSync(nativeData, JSON.stringify(data))
}
