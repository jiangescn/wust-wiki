import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'parse5'
import { nearbyPlaces, nearbyDefaultCampuses } from '../../app/data/nearby.ts'
import { campusTimes } from '../../app/utils/schedule.ts'
import { navigationCategories } from '../../app/data/navigation.ts'
import { navigationExtras, wikiLifeCategory } from '../../app/data/navigation-extra.ts'
import { homeEntries } from '../../app/data/wiki.ts'

const root = fileURLToPath(new URL('../../', import.meta.url))
const read = p => fs.readFileSync(path.join(root,p), 'utf8')
const json = p => JSON.parse(read('app/data/' + p + '.json'))
const attr = (n,k) => n.attrs?.find(a=>a.name===k)?.value
const cls = (n,k) => attr(n,'class')?.split(/\s+/).includes(k)
function all(n, f) {return [...(f(n)?[n]:[]), ...(n.childNodes||[]).flatMap(c=>all(c,f))]}
function plain(n) {return n.nodeName==='#text'?n.value:(n.childNodes||[]).map(plain).join('')}
const links = all(parse(read('.output/public/articles/index.html')),n=>cls(n,'wiki-article-list'))[0]
const articles = {}
for (const a of all(links,n=>n.tagName==='a')) {
  const route = attr(a,'href')
  if(route.split('/').some(part=>part.startsWith('.'))) continue
  articles[route]={title:plain(a)}
}
if(!articles['/campus/accommodation']) throw Error('缺少住宿正文')
const data={times:campusTimes, articles,homeEntries,places:[...nearbyDefaultCampuses,...nearbyPlaces],navigation:[...navigationCategories,wikiLifeCategory,...navigationExtras], curricula:json('curricula'), contests:{2025:json('competitions-2025'),2024:json('competitions-2024')}}
fs.writeFileSync(path.join(root,'mobile/assets/native.json'),JSON.stringify(data))
console.log(Object.keys(articles).length+' 篇文章；'+data.places.length+' 个地图点')
