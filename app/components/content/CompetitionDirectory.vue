<script setup lang="ts">
import WikiMotion from '../WikiMotion.vue'
import DirectoryState from '../DirectoryState.vue'
import competitions from '~/data/competitions-2024.json'
import officialUrls from '~/data/competition-official-urls.json'

// Temporarily hide per-entry source metadata; retain the data and UI for restoration.
const showSourceDetails = false
const keyword = ref('')
const level = ref('all')
const organizer = ref('all')
const audience = ref('all')
const visible = ref(20)
const searchInput = useTemplateRef('searchInput')
const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
const levelOptions = [{ label: '全部类别', value: 'all' }, ...levels.map(value => ({ value, label: `${value} 类 · ${competitions.filter(item => item.level === value).length} 项` }))]
const organizerOptions = [{ label: '全部组织单位', value: 'all' }, ...[...new Set(competitions.flatMap(item => item.organizers))].map(value => ({ label: value, value }))]
const audienceOptions = [
  { label: '全部面向对象', value: 'all' },
  { label: '本科生（含全校学生）', value: '本科生' },
  { label: '研究生（含全校学生）', value: '研究生' },
  { label: '原表未注明', value: 'unknown' },
]
const filtered = computed(() => {
  const term = keyword.value.trim().toLocaleLowerCase()
  return competitions.filter(item =>
    (level.value === 'all' || item.level === level.value)
    && (organizer.value === 'all' || item.organizers.includes(organizer.value))
    && (audience.value === 'all' || (audience.value === 'unknown' ? item.audience === null : item.audience === audience.value || item.audience === '全校学生'))
    && (!term || [String(item.id), item.name, item.host, ...item.organizers].join(' ').toLocaleLowerCase().includes(term)),
  )
})
const shown = computed(() => filtered.value.slice(0, visible.value))
const officialUrl = (id: number) => officialUrls[String(id) as keyof typeof officialUrls] || ''
watch([keyword, level, organizer, audience], () => { visible.value = 20 })
function reset() { keyword.value = ''; level.value = 'all'; organizer.value = 'all'; audience.value = 'all' }
async function resetFromEmpty() {
  reset()
  await nextTick()
  searchInput.value?.inputRef?.focus({ preventScroll: true })
}
</script>

<template>
  <section class="competition-directory not-prose" aria-label="2024 年竞赛分类目录">
    <div class="competition-search">
      <UInput ref="searchInput" v-model="keyword" icon="i-lucide-search" placeholder="搜索竞赛、组织单位、主办单位" aria-label="搜索竞赛" class="w-full" />
      <UButton variant="ghost" color="neutral" @click="reset">重置筛选</UButton>
    </div>
    <div class="competition-filters">
      <USelect v-model="level" :items="levelOptions" aria-label="筛选竞赛类别" class="w-full" />
      <USelect v-model="organizer" :items="organizerOptions" aria-label="筛选组织单位" class="w-full" />
      <USelect v-model="audience" :items="audienceOptions" aria-label="筛选面向对象" class="w-full" />
    </div>
    <p class="competition-count" role="status">找到 {{ filtered.length }} 项 · 按原表顺序排列 · 2024 年版本</p>
    <p v-if="audience !== 'all' && audience !== 'unknown'" class="competition-hint">此筛选包含原表标注“全校学生”的项目，不包含面向对象未注明的项目；当届报名资格仍需查阅赛事通知。</p>
    <WikiMotion :change-key="JSON.stringify([keyword.trim(), level, organizer, audience])" :resize="false" :fade-from="0.9">
    <DirectoryState v-if="!filtered.length" title="没有找到符合条件的竞赛" description="可以更换关键词或清除筛选条件。" action-label="清除筛选条件" @action="resetFromEmpty" />
    <div class="competition-list">
      <details v-for="item in shown" :key="item.id" class="competition-item" :data-contest-id="item.id">
        <summary>
          <UBadge color="primary" variant="subtle" class="competition-level">{{ item.level }}</UBadge>
          <span class="competition-copy">
            <span class="competition-name">{{ item.name }}</span>
            <span class="competition-meta">{{ item.organizers.join('、') }} · {{ item.audience || '面向对象：原表未注明' }}</span>
          </span>
          <span class="competition-toggle" aria-hidden="true">+</span>
        </summary>
        <div class="competition-detail">
          <dl>
            <div v-if="showSourceDetails"><dt>原表序号</dt><dd>{{ item.id }}</dd></div>
            <div><dt>主办单位</dt><dd>{{ item.host }}</dd></div>
            <div><dt>列入排行榜</dt><dd>{{ item.ranked ? '是' : '否' }}</dd></div>
            <div>
              <dt>参考官网链接</dt>
              <dd>
                <LinkCard
                  v-if="officialUrl(item.id)"
                  :link="officialUrl(item.id)"
                  title="访问赛事官网"
                  :description="officialUrl(item.id)"
                  :aria-label="`${item.name}：访问参考官网`"
                  class="competition-official-link"
                />
              </dd>
            </div>
            <div v-if="showSourceDetails"><dt>来源位置</dt><dd>PDF 第 {{ item.pdfPage }} 页，原文页码 {{ item.printedPage }}</dd></div>
          </dl>
          <UButton v-if="showSourceDetails" :to="`/files/competition-catalog-2024.pdf#page=${item.pdfPage}`" target="_blank" color="neutral" variant="link" size="sm">查看原表这一页 →</UButton>
        </div>
      </details>
    </div>
    <div v-if="visible < filtered.length" class="competition-more"><UButton color="neutral" variant="outline" @click="visible += 20">显示更多（{{ shown.length }} / {{ filtered.length }}）</UButton></div>
    <noscript>请启用 JavaScript 使用搜索和筛选。</noscript>
  </WikiMotion>
  </section>
</template>

<style scoped>
.competition-directory { font-family: var(--font-sans); color: var(--ui-text); line-height: 1.5; }
.competition-search { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: .5rem; }
.competition-filters { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.4fr) minmax(0, 1.4fr); gap: .5rem; margin-top: .6rem; }
.competition-count, .competition-hint { color: var(--ui-text-muted); font-size: .8rem; margin: .85rem 0 !important; }
.competition-list { border-top: 1px solid var(--ui-border); }
.competition-item { border-bottom: 1px solid var(--ui-border); border-radius: .5rem; }
.competition-item[open] { background: var(--ui-bg-muted); }
.competition-item summary { display: flex; align-items: flex-start; gap: .8rem; padding: 1rem .75rem; border-radius: .5rem; list-style: none; cursor: pointer; }
.competition-item summary::-webkit-details-marker { display: none; }
.competition-item:not([open]) summary:hover { background: var(--ui-bg-muted); }
.competition-item summary:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 2px; border-radius: .4rem; }
.competition-level { flex: none; margin-top: .15rem; }
.competition-copy { flex: 1; min-width: 0; }
.competition-name { display: block; font-size: .95rem; font-weight: 600; color: var(--ui-text-highlighted); overflow-wrap: anywhere; }
.competition-meta { display: block; font-size: .75rem; color: var(--ui-text-muted); margin-top: .4rem; overflow-wrap: anywhere; }
.competition-toggle { color: var(--ui-text-muted); font-size: 1.2rem; transition: transform .15s; }
.competition-item[open] .competition-toggle { transform: rotate(45deg); }
.competition-detail { padding: .9rem 1rem; }
.competition-detail dl { margin: 0 0 .6rem; font-size: .8rem; }
.competition-detail dl > div { display: grid; grid-template-columns: 6rem minmax(0, 1fr); gap: .5rem; padding: .25rem 0; }
.competition-detail dt { color: var(--ui-text-muted); }
.competition-detail dd { margin: 0; overflow-wrap: anywhere; }
.competition-official-link { margin: 0; padding: .75rem; gap: .75rem; }
.competition-more { display: flex; justify-content: center; margin-top: 1.25rem; }
@media (max-width: 640px) {
  .competition-filters { grid-template-columns: minmax(0, 1fr); }
  .competition-item summary { gap: .55rem; }
  .competition-name { font-size: .9rem; }
  .competition-detail { padding: .75rem; }
  .competition-detail dl > div { grid-template-columns: 5.4rem minmax(0, 1fr); }
}
@media (prefers-reduced-motion: reduce) { .competition-toggle { transition: none; } }
</style>
