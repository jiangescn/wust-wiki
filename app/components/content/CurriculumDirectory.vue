<script setup lang="ts">
// The chosen flat layout shares the archived catalog and document URLs.
import catalog from '~/data/curricula.json'
import DirectoryState from '../DirectoryState.vue'
import WikiMotion from '../WikiMotion.vue'
import { curriculumLabel, curriculumTitle as title } from '~/utils/curriculum-labels'

const level = ref('本科')
const keyword = ref('')
const onlyAvailable = ref(false)
const searchInput = useTemplateRef('searchInput')
const collegeAnchors = new Map<string, string>()
for (const item of catalog.records) {
  const key = `${item.level}/${item.college}`
  if (!collegeAnchors.has(key)) collegeAnchors.set(key, `curricula-${item.id}`)
}
const groups = computed(() => {
  const query = keyword.value.trim().toLocaleLowerCase()
  const records = catalog.records.filter(item => item.level === level.value
    && (!onlyAvailable.value || item.documents.length)
    && (!query || [item.college, item.program, ...item.documents.map(doc => `${curriculumLabel(doc.title)} ${doc.version}`)].join(' ').toLocaleLowerCase().includes(query)))
  return [...new Set(records.map(item => item.college))].map(college => ({
    college,
    id: collegeAnchors.get(`${level.value}/${college}`),
    programs: records.filter(item => item.college === college),
  }))
})
const count = computed(() => groups.value.reduce((sum, group) => sum + group.programs.length, 0))
async function clearFilters() {
  keyword.value = ''
  onlyAvailable.value = false
  await nextTick()
  searchInput.value?.focus({ preventScroll: true })
}
</script>

<template>
  <section class="flat-curricula not-prose" aria-label="培养方案查询">
    <div class="flat-toolbar">
      <div class="flat-levels" role="group" aria-label="培养层次">
        <button v-for="value in ['本科', '研究生']" :key="value" type="button" :aria-pressed="level === value" @click="level = value">{{ value }}</button>
      </div>
      <input ref="searchInput" v-model="keyword" type="search" aria-label="搜索培养方案" placeholder="搜索学院、专业、年级" />
      <label class="flat-available"><input v-model="onlyAvailable" type="checkbox" />仅有资料</label>
    </div>
    <WikiMotion :change-key="`${level}/${keyword}/${onlyAvailable}`" :resize="false" :fade-from="0.85">
      <p class="flat-count" role="status">{{ groups.length }} 个学院 · {{ count }} 个专业</p>
      <nav v-if="groups.length > 1" class="flat-index flat-index-desktop" aria-label="学院快速定位">
        <a v-for="group in groups" :key="group.college" :href="`#${group.id}`">{{ group.college }}</a>
      </nav>
      <details v-if="groups.length > 1" class="flat-index-mobile">
        <summary>
          <span>学院定位 <span class="flat-index-total">{{ groups.length }} 个学院</span></span>
          <svg class="flat-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
        </summary>
        <nav class="flat-index" aria-label="学院快速定位">
          <a v-for="group in groups" :key="group.college" :href="`#${group.id}`">{{ group.college }}</a>
        </nav>
      </details>
      <DirectoryState v-if="!groups.length" title="没有匹配的培养方案" description="试试其他关键词，或清除筛选条件。" action-label="清除筛选" @action="clearFilters" />
      <template v-for="(group, index) in groups" :key="group.college">
      <hr v-if="index > 0" class="flat-college-divider" />
      <section :id="group.id" class="flat-college" :aria-label="group.college" tabindex="-1">
        <header class="flat-college-heading"><h2>{{ group.college }}</h2><span>{{ group.programs.length }} 个专业</span></header>
        <div class="flat-grid">
          <article v-for="item in group.programs" :key="item.id" class="flat-card" :class="{ 'flat-card-missing': !item.documents.length }">
            <div class="flat-card-heading"><h3>{{ curriculumLabel(item.program) }}</h3><span v-if="item.documents.length">{{ item.documents.length }} 份</span></div>
            <template v-if="item.documents.length">
              <div v-for="doc in item.documents.slice(0, 2)" :key="doc.url" class="flat-doc">
                <p class="flat-doc-title">{{ title(doc.title) }}</p>
                <div v-if="curriculumLabel(doc.version)" class="flat-meta">{{ curriculumLabel(doc.version) }}</div>
                <div class="flat-actions">
                  <a :href="doc.url" :target="doc.format === 'DOC' ? undefined : '_blank'" rel="noopener noreferrer" :download="doc.format === 'DOC' ? `${curriculumLabel(doc.title)}.doc` : undefined">{{ doc.format === 'DOC' ? '下载 DOC' : doc.format === '网页' ? '官网正文 ↗' : '查看 PDF ↗' }}</a>
                  <a v-if="doc.format === 'PDF'" :href="doc.url" :download="`${curriculumLabel(doc.title)}.pdf`">下载</a>
                </div>
              </div>
              <details v-if="item.documents.length > 2" class="flat-more curriculum-more">
                <summary><span>其他版本（{{ item.documents.length - 2 }}）</span><svg class="flat-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></summary>
                <div v-for="doc in item.documents.slice(2)" :key="doc.url" class="flat-doc">
                  <p class="flat-doc-title">{{ title(doc.title) }}</p>
                  <div v-if="curriculumLabel(doc.version)" class="flat-meta">{{ curriculumLabel(doc.version) }}</div>
                  <div class="flat-actions">
                    <a :href="doc.url" :target="doc.format === 'DOC' ? undefined : '_blank'" rel="noopener noreferrer" :download="doc.format === 'DOC' ? `${curriculumLabel(doc.title)}.doc` : undefined">{{ doc.format === 'DOC' ? '下载 DOC' : doc.format === '网页' ? '官网正文 ↗' : '查看 PDF ↗' }}</a>
                    <a v-if="doc.format === 'PDF'" :href="doc.url" :download="`${curriculumLabel(doc.title)}.pdf`">下载</a>
                  </div>
                </div>
              </details>
            </template>
            <template v-else>
              <p class="flat-missing">{{ item.status === '附件需验证码' ? '官网附件需验证码' : '暂无公开完整方案' }}</p>
              <div v-if="item.sources.length" class="flat-source">
                <a v-for="(source, index) in item.sources" :key="source" :href="source" target="_blank" rel="noopener noreferrer">官网入口 {{ index + 1 }}</a>
              </div>
            </template>
          </article>
        </div>
      </section>
      </template>
    </WikiMotion>
  </section>
</template>

<style scoped>
.flat-curricula { --curriculum-radius: 12px; --curriculum-control-radius: 6px; margin-block: 1rem; color: var(--ui-text); font-size: 14px; }
.flat-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem; }
.flat-levels { display: flex; padding: 2px; border: 1px solid var(--ui-border); border-radius: var(--curriculum-control-radius); background: var(--ui-bg-elevated); }
.flat-levels button { height: 28px; padding-inline: 12px; border-radius: 4px; color: var(--ui-text-muted); cursor: pointer; transition: color 160ms ease, background-color 160ms ease, box-shadow 160ms ease; }
.flat-levels button[aria-pressed=true] { color: var(--ui-primary); background: var(--ui-bg); box-shadow: 0 1px 3px #0001; }
.flat-toolbar > input { flex: 1; min-width: 160px; height: 34px; padding: 0 10px; border: 1px solid var(--ui-border-accented); border-radius: var(--curriculum-control-radius); background: var(--ui-bg); font: inherit; transition: border-color 160ms ease; }
.flat-available { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--ui-text-muted); }
.flat-available input { accent-color: var(--ui-primary); }
.flat-curricula :is(button, input, a, summary):focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 3px; }
.flat-count { margin-block: .75rem; font-size: 12px; color: var(--ui-text-muted); line-height: 1.7; }
.flat-index { display: flex; flex-wrap: wrap; gap: 6px; padding-bottom: .5rem; }
.flat-index a { padding: 4px 8px; border-radius: var(--curriculum-control-radius); background: var(--ui-bg-elevated); color: var(--ui-text-muted); font-size: 12px; text-decoration: none; transition: color 160ms ease, background-color 160ms ease; }
.flat-index a:hover { color: var(--ui-primary); }
.flat-index-mobile { display: none; }
.flat-college { margin-top: 1.75rem; scroll-margin-top: 90px; }
.flat-college:focus { outline: none; }
.flat-college:focus-visible > .flat-college-heading { outline: 2px solid var(--ui-primary); outline-offset: 4px; }
.flat-college:target > .flat-college-heading { border-bottom-color: var(--ui-primary); }
.flat-college:target > .flat-college-heading h2 { color: var(--ui-primary); }
.flat-college-divider { margin: 2rem 0; border: 0; border-top: 2px solid var(--ui-border-accented); }
.flat-college-heading { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: .5rem 1rem; margin-bottom: 1rem; padding-bottom: .75rem; border-bottom: 1px solid var(--ui-border); }
.flat-college-heading h2 { margin: 0; font-size: 24px; font-weight: 650; line-height: 1.5; color: var(--ui-text-highlighted); }
.flat-college-heading > span { flex-shrink: 0; font-size: 12px; color: var(--ui-text-muted); }
.flat-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .75rem; align-items: start; }
.flat-card { min-width: 0; border: 1px solid var(--ui-border); border-radius: var(--curriculum-radius); padding: .875rem; background: var(--ui-bg); overflow-wrap: anywhere; transition: border-color 180ms ease, box-shadow 180ms ease; }
.flat-card:focus-within { border-color: var(--ui-primary); }
@media (hover: hover) {
  .flat-card:hover { border-color: var(--ui-border-accented); box-shadow: 0 3px 12px color-mix(in srgb, var(--ui-text) 5%, transparent); }
}
.flat-card-heading { display: flex; justify-content: space-between; gap: .5rem; }
.flat-card-heading h3 { margin: 0; font-size: 15px; line-height: 1.5; font-weight: 600; }
.flat-card-heading > span { flex-shrink: 0; color: var(--ui-text-dimmed); font-size: 12px; }
.flat-card-missing { background: var(--ui-bg-elevated); }
.flat-doc { margin-top: .75rem; padding-top: .625rem; border-top: 1px solid var(--ui-border); }
.flat-doc-title { margin: 0 0 .375rem; font-size: 13px; line-height: 1.6; }
.flat-meta { display: flex; flex-wrap: wrap; gap: 4px 8px; color: var(--ui-text-muted); font-size: 11px; }
.flat-actions { display: flex; flex-wrap: wrap; gap: .5rem 1rem; align-items: baseline; margin-top: .5rem; font-size: 12px; }
.flat-curricula a { color: var(--ui-primary); text-underline-offset: 3px; }
.flat-source { color: var(--ui-text-muted); font-size: 12px; line-height: 1.7; }
.flat-source a { display: inline-block; margin-right: .75rem; }
.flat-more { margin-top: .75rem; font-size: 12px; color: var(--ui-text-muted); }
.flat-more > summary { display: flex; align-items: center; gap: .375rem; width: fit-content; min-height: 30px; padding: 2px 6px; margin-left: -6px; border-radius: var(--curriculum-control-radius); list-style: none; cursor: pointer; transition: color 160ms ease, background-color 160ms ease; }
.flat-more > summary::-webkit-details-marker { display: none; }
.flat-more > summary:hover { color: var(--ui-primary); background: var(--ui-bg-elevated); }
.flat-chevron { display: block; flex: 0 0 16px; transition: transform 220ms ease; }
.flat-more[open] .flat-chevron { transform: rotate(180deg); }
.flat-missing { margin: .5rem 0; font-size: 12px; color: var(--ui-text-dimmed); }
@media (max-width: 640px) {
  .flat-index-desktop { display: none; }
  .flat-index-mobile { display: block; border: 1px solid var(--ui-border); border-radius: var(--curriculum-control-radius); }
  .flat-index-mobile > summary { display: flex; align-items: center; justify-content: space-between; gap: .75rem; min-height: 44px; padding: .625rem .75rem; list-style: none; cursor: pointer; color: var(--ui-text-highlighted); }
  .flat-index-mobile > summary::-webkit-details-marker { display: none; }
  .flat-index-mobile[open] > summary .flat-chevron { transform: rotate(180deg); }
  .flat-index-total { margin-left: .5rem; color: var(--ui-text-muted); font-size: 12px; }
  .flat-index-mobile .flat-index { padding: 0 .75rem .75rem; }
  .flat-index-mobile .flat-index a { display: flex; align-items: center; min-height: 36px; }
  .flat-grid { grid-template-columns: minmax(0, 1fr); }
  .flat-toolbar > input { min-width: 0; width: 100%; flex-basis: 100%; order: 3; }
  .flat-available { margin-left: auto; }
  .flat-college-heading h2 { font-size: 20px; }
}
@media (prefers-reduced-motion: reduce) {
  .flat-index-mobile .flat-chevron { transition: none; }
}
</style>
