<script setup lang="ts">
// Layout adapted from xupt-wiki/xupt-nav, GPL-3.0; see vendor/xupt-nav/README.md.
import { navigationCategories, type NavigationCategory, type NavigationLink } from '~/data/navigation'
import { navigationExtras, wikiLifeCategory } from '~/data/navigation-extra'

definePageMeta({ layout: false })
useSeoMeta({ title: '武科大导航', description: '武汉科技大学常用网站、教务学习、校园服务与校园生活入口。' })

const search = ref('')
const primaryCategories = [...navigationCategories, wikiLifeCategory]
const allCategories = [...primaryCategories, ...navigationExtras]
const total = allCategories.reduce((count, category) => count + category.links.length, 0)
const keywords = computed(() => search.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean))
function filterCategories(categories: NavigationCategory[]) {
  return categories.map(category => ({
    ...category,
    links: category.links.filter(link => {
      const haystack = [category.title, link.title, link.description, link.url, ...(link.keywords || [])].join(' ').toLocaleLowerCase()
      return keywords.value.every(word => haystack.includes(word))
    }),
  })).filter(category => category.links.length)
}
const primary = computed(() => filterCategories(primaryCategories))
const extras = computed(() => filterCategories(navigationExtras))
const resultCount = computed(() => [...primary.value, ...extras.value].reduce((count, category) => count + category.links.length, 0))
const isExternal = (link: NavigationLink) => /^https?:\/\//.test(link.url)
const linkTitle = (link: NavigationLink) => [link.description, link.note, isExternal(link) ? `${link.url}（新窗口打开）` : '在 Wiki 内打开'].filter(Boolean).join(' · ')
const categoryIcons: Record<string, string> = { study: 'i-lucide-book-open', campus: 'i-lucide-building-2', future: 'i-lucide-graduation-cap', 'wiki-life': 'i-lucide-map-pin' }
</script>

<template>
  <main class="co-navigation">
    <header class="between nav-heading">
      <div>
        <h1><UIcon name="i-lucide-compass" aria-hidden="true" /> 武科大导航</h1>
        <p class="nav-intro">武汉科技大学非官方网址导航</p>
      </div>
      <div class="nav-search">
        <label class="sr-only" for="navigation-search">搜索导航</label>
        <UIcon name="i-lucide-search" aria-hidden="true" />
        <input id="navigation-search" v-model="search" type="search" placeholder="搜索名称、用途或网址" autocomplete="off" @keydown.esc="search = ''">
        <button v-if="search" type="button" aria-label="清空搜索" @click="search = ''">×</button>
      </div>
    </header>

    <nav class="dim list nav-shortcuts" aria-label="导航快捷入口">
      <NuxtLink to="/">WUST Wiki</NuxtLink>
      <NuxtLink to="/study/curriculum">查课表</NuxtLink>
      <NuxtLink to="/study/grades">查成绩</NuxtLink>
      <NuxtLink to="/life/food">吃在武科</NuxtLink>
      <span class="nav-count" role="status" aria-live="polite">{{ keywords.length ? `找到 ${resultCount} 个入口` : `${total} 个常用入口` }}</span>
    </nav>

    <div v-if="primary.length" class="col-auto navlist" aria-label="武科大常用入口">
      <section v-for="category in primary" :key="category.id" class="card" :aria-labelledby="`nav-${category.id}`">
        <h2 :id="`nav-${category.id}`"><UIcon :name="categoryIcons[category.id]" aria-hidden="true" /> {{ category.title }}</h2>
        <ul class="list">
          <li v-for="link in category.links" :key="link.url">
            <NuxtLink :to="link.url" :external="isExternal(link)" :target="isExternal(link) ? '_blank' : undefined" :rel="isExternal(link) ? 'noopener noreferrer' : undefined" :title="linkTitle(link)">
              <span class="nav-link-title"><UIcon :name="link.icon" class="nav-link-icon" aria-hidden="true" />{{ link.title }}</span>
              <small class="nav-link-description">{{ link.description }}</small>
            </NuxtLink>
          </li>
        </ul>
      </section>
    </div>

    <template v-if="extras.length">
      <h2 id="discover" class="more-title"><UIcon name="i-lucide-grid-2x2" aria-hidden="true" /> 发现更多</h2>
      <div class="col-auto navlist" aria-label="发现更多">
        <section v-for="category in extras" :key="category.id" class="card" :aria-labelledby="`nav-${category.id}`">
          <h3 :id="`nav-${category.id}`"><UIcon :name="category.icon || 'lucide:compass'" aria-hidden="true" /> {{ category.title }}</h3>
          <ul class="list">
            <li v-for="link in category.links" :key="link.url">
              <NuxtLink :to="link.url" :external="isExternal(link)" :target="isExternal(link) ? '_blank' : undefined" :rel="isExternal(link) ? 'noopener noreferrer' : undefined" :title="linkTitle(link)">
                <span class="nav-link-title"><UIcon :name="link.icon" class="nav-link-icon" aria-hidden="true" />{{ link.title }}</span>
                <small class="nav-link-description">{{ link.description }}</small>
              </NuxtLink>
            </li>
          </ul>
        </section>
      </div>
    </template>

    <div v-if="!resultCount" class="card nav-empty">
      <p>没有找到“{{ search.trim() }}”相关入口。</p>
      <button type="button" @click="search = ''">清空搜索，查看全部</button>
    </div>

    <footer class="between nav-footer">
      <p>部分校内系统需校园网或学校账号，具体以目标网站提示为准。</p>
      <p>参考 <a href="https://www.cooo.site/" target="_blank" rel="noopener noreferrer">CO 导航</a> · <a href="https://github.com/xupt-wiki/xupt-nav" target="_blank" rel="noopener noreferrer">纸鹿 / GPL-3.0</a></p>
    </footer>
  </main>
</template>

<style scoped src="../assets/co-navigation.css"></style>

<style scoped>
.nav-heading { gap: 1rem; }
h1 { display: flex; align-items: center; gap: .4em; font-size: 2rem; font-weight: 650; }
.nav-intro { margin-top: .4em; color: var(--text2); font-size: .75em; }
.nav-search { display: flex; align-items: center; gap: .6em; width: 21em; max-width: 100%; border: 1px solid var(--line); border-radius: .5rem; background: var(--bg1); padding: .6em .8em; color: var(--text2); font-size: .875rem; }
.nav-search:focus-within { border-color: var(--ac1); outline: 2px solid var(--ac3); }
.nav-search input { width: 100%; min-width: 0; outline: none; background: transparent; }
.nav-search input::-webkit-search-cancel-button { display: none; }
.nav-search button { cursor: pointer; font-size: 1.25em; line-height: 1; }
.nav-shortcuts { margin-bottom: 1.2rem; color: var(--text2); }
.nav-count { margin-left: auto; color: var(--text3); }
.card h2, .card h3, .more-title { display: flex; align-items: center; gap: .4em; font-size: 1em; font-weight: 650; }
.more-title { font-size: 1.1em; scroll-margin-top: 6rem; }
.list { list-style: none; padding: 0; }
.list li { max-width: 100%; flex-shrink: 0; }
.list a { max-width: 100%; }
.nav-link-title { display: flex; align-items: center; gap: .35em; color: var(--ui-text); white-space: nowrap; }
.nav-link-icon { width: 1em; height: 1em; flex-shrink: 0; }
/* Real text replaces data-sub pseudo-elements for accessible descriptions. */
.nav-link-description { display: block; margin-top: .25em; color: var(--text2); font-size: .75rem; line-height: 1.5; white-space: nowrap; }
.list a:hover .nav-link-title { color: var(--ac1); }
.list a:hover .nav-link-description { color: inherit; }
a:focus-visible, button:focus-visible { outline: 2px solid var(--ac1); outline-offset: 4px; }
.nav-footer { margin-top: 1.5rem; color: var(--text2); font-size: .7em; }
.nav-empty { padding: .8rem 0; }
.nav-empty button { color: var(--ac1); cursor: pointer; }
@media (max-width: 45em) {
  .nav-heading { align-items: stretch; flex-direction: column; }
  .nav-search { width: 100%; font-size: 1rem; }
  .nav-count { width: 100%; margin: 0; }
}
</style>
