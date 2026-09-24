<script setup lang="ts">
import { blogProseComponents } from '~/utils/blog-prose'
definePageMeta({ layout: false, alias: ['/previews/example'] })
useSeoMeta({ title: '原博客完整组件示例' })
const { data: page } = await useAsyncData('blog-component-example', () => queryCollection('docs').path('/blog-components').first())
const names = ['Alert', 'Badge', 'Blur', 'CardList', 'Chat', 'Copy', 'EmojiClock', 'FeedCard', 'FeedGroup', 'Folding', 'Key', 'LinkBanner', 'LinkCard', 'MdTitle', 'Mermaid', 'MusicScore', 'Pic', 'Poetry', 'ProseA', 'ProseCode', 'ProsePre', 'ProseTable', 'Quote', 'Tab', 'Timeline', 'Tip', 'VideoEmbed']
const components = Object.fromEntries(names.map(name => [name.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase(), `Blog${name}`]))
Object.assign(components, blogProseComponents, { 'blog-header': 'BlogHeader' })
// Keep paragraph slots and heading anchors; other native tags use the original article CSS.
// The original rehype plugin extracts these trees into Nuxt Content metadata.
const metaSlots = computed(() => (page.value?.meta?.slots || {}) as Record<string, { type: 'minimark'; value: unknown[]; props?: { title?: string } }>)
</script>

<template>
  <main v-if="page" class="blog-components blog-showcase">
    <header class="showcase-header"><h1>{{ page.title }}</h1><p><a href="https://blog.zhilu.site/previews/example" target="_blank" rel="noopener noreferrer">原示例页 ↗</a> · 原组件与示例正文移植</p></header>
    <div class="showcase-layout">
      <!-- Only navigation is repeated; article and interactive slots stay mounted once. -->
      <details v-if="page.body.toc?.links?.length" class="showcase-toc showcase-mobile-toc">
        <summary>本页目录</summary>
        <nav aria-label="本页目录"><NuxtLink v-for="item in page.body.toc.links" :key="item.id" :to="`#${encodeURIComponent(item.id)}`">{{ item.text }}</NuxtLink></nav>
      </details>
      <div class="showcase-main">
        <ContentRenderer :value="page" :components="components" :prose="false" class="article md-tech" tag="article" />
        <section v-if="metaSlots.copyright" class="article"><h2>{{ metaSlots.copyright.props?.title }}</h2><ContentRenderer :value="metaSlots.copyright" :components="components" /></section>
      </div>
      <aside class="showcase-aside" aria-label="示例目录与侧栏插槽">
        <details v-if="page.body.toc?.links?.length" class="showcase-toc showcase-desktop-toc" open><summary>本页目录</summary><nav aria-label="本页目录"><NuxtLink v-for="item in page.body.toc.links" :key="item.id" :to="`#${encodeURIComponent(item.id)}`">{{ item.text }}</NuxtLink></nav></details>
        <section v-for="(slot, key) in Object.fromEntries(Object.entries(metaSlots).filter(([key]) => key.startsWith('aside-')))" :key="key" class="card article"><h2 v-if="slot.props?.title">{{ slot.props.title }}</h2><ContentRenderer :value="slot" :components="components" /></section>
      </aside>
    </div>
  </main>
</template>

<style scoped>
.blog-showcase { max-width:1280px;margin:auto;padding:2rem 1rem 4rem; }
.showcase-header { padding:0 1rem 1rem; }.showcase-header h1 { font-size:2rem;font-weight:700; }.showcase-header p { margin-top:.5rem;color:var(--c-text-2);font-size:.85rem; }
.showcase-layout { display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:2rem; }.showcase-main { min-width:0; }.showcase-aside { min-width:0;align-self:start;position:sticky;top:5rem;max-height:calc(100dvh - 6rem);overflow:auto; }.showcase-aside { font-size:.85rem; }.showcase-aside h2 { font-weight:600; }
.showcase-toc nav { display:grid;gap:.6rem;margin:1rem 0;overflow-wrap:anywhere; }
.showcase-aside { scrollbar-width:none;overscroll-behavior:contain; }
.showcase-aside::-webkit-scrollbar { display:none; }
.showcase-toc summary { cursor:pointer;font-weight:600; }
.showcase-toc summary::marker { color:var(--ui-primary); }
.showcase-toc :is(summary, a):focus-visible { outline:2px solid var(--ui-primary);outline-offset:3px;border-radius:3px; }
.showcase-mobile-toc { display:none; }
.showcase-aside > section { margin:1rem 0;padding:1rem;overflow-wrap:anywhere; }
.showcase-aside :deep(.link-card) { max-width:100%; }
@media(max-width:1024px) {
  .showcase-layout { grid-template-columns:minmax(0,1fr);gap:1.5rem; }
  .showcase-mobile-toc { display:block;border:1px solid var(--ui-border);border-radius:.75rem;background:var(--ui-bg-muted);font-size:.875rem; }
  .showcase-mobile-toc summary { padding:.85rem 1rem; }
  .showcase-mobile-toc nav { margin:0;padding:.25rem 1rem 1rem; }
  .showcase-desktop-toc { display:none; }
  .showcase-aside { position:static;max-height:none;overflow:visible;overscroll-behavior:auto;width:100%;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1rem; }
  .showcase-aside > section { margin:0; }
}
@media(max-width:600px) { .showcase-aside { grid-template-columns:minmax(0,1fr); } }
</style>

