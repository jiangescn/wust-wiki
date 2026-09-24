<script setup lang="ts">
// One reference design, requested by the user. Synthetic data; no API or storage.
type DemoCourse = { id: string; name: string; term: string; score: number; credit: number; point: number; nature: string; attempt: string }
const courses: DemoCourse[] = [
  { id: 'DEMO-01', name: '高等数学 A（二）', term: '2025–2026 / 第二学期', score: 87, credit: 5, point: 3.7, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-02', name: '大学英语（二）', term: '2025–2026 / 第二学期', score: 92, credit: 3, point: 4, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-03', name: '程序设计基础', term: '2025–2026 / 第二学期', score: 84, credit: 4, point: 3.3, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-04', name: '大学物理（一）', term: '2025–2026 / 第二学期', score: 76, credit: 3.5, point: 2.7, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-05', name: '体育（二）', term: '2025–2026 / 第二学期', score: 90, credit: 1, point: 4, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-06', name: '艺术鉴赏', term: '2025–2026 / 第二学期', score: 95, credit: 2, point: 4, nature: '选修', attempt: '正常考试' },
  { id: 'DEMO-07', name: '高等数学 A（一）', term: '2025–2026 / 第一学期', score: 82, credit: 5, point: 3.3, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-08', name: '计算机导论', term: '2025–2026 / 第一学期', score: 89, credit: 2, point: 3.7, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-09', name: '线性代数', term: '2025–2026 / 第一学期', score: 58, credit: 2.5, point: 0, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-10', name: '大学英语（一）', term: '2025–2026 / 第一学期', score: 86, credit: 3, point: 3.7, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-11', name: '体育（一）', term: '2025–2026 / 第一学期', score: 88, credit: 1, point: 3.7, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-12', name: '中国近现代史纲要', term: '2025–2026 / 第一学期', score: 83, credit: 3, point: 3.3, nature: '必修', attempt: '正常考试' },
  { id: 'DEMO-13', name: '大学生心理健康', term: '2025–2026 / 第一学期', score: 91, credit: 2, point: 4, nature: '必修', attempt: '正常考试' },
]
const bands = [
  ['90–100', 'A', '4.0'], ['85–89', 'A−', '3.7'], ['82–84', 'B+', '3.3'],
  ['78–81', 'B', '3.0'], ['75–77', 'B−', '2.7'], ['72–74', 'C+', '2.3'],
  ['68–71', 'C', '2.0'], ['64–67', 'C−', '1.5'], ['60–63', 'D', '1.0'], ['60 以下', 'F', '0'],
]
const terms = [...new Set(courses.map(course => course.term))]
const term = ref('')
const search = ref('')
const expanded = ref(false)
watch([term, search], () => { expanded.value = false })
const scaleOpen = ref(false)
const detailOpen = ref(false)
const detail = ref<DemoCourse>()
const selected = computed(() => courses.filter(course => !term.value || course.term === term.value))
const credits = computed(() => selected.value.reduce((sum, course) => sum + course.credit, 0))
const gpa = computed(() => (selected.value.reduce((sum, course) => sum + course.credit * course.point, 0) / credits.value).toFixed(2))
const filtered = computed(() => selected.value.filter(course => `${course.name} ${course.id}`.toLowerCase().includes(search.value.trim().toLowerCase())))
const visible = computed(() => expanded.value ? filtered.value : filtered.value.slice(0, 6))
const groups = computed(() => terms.map(label => ({ label, courses: visible.value.filter(course => course.term === label) })).filter(group => group.courses.length))
function showDetail(course: DemoCourse) { detail.value = course; detailOpen.value = true }
</script>

<template>
  <section class="grade-prototype" aria-label="成绩展示样例">
    <div class="prototype-caption"><UBadge color="neutral" variant="subtle">演示数据</UBadge><NuxtLink to="/study/grades">返回查询 ↗</NuxtLink></div>
    <div class="grade-overview">
      <div class="overview-title"><h2>成绩概览</h2><UButton color="neutral" variant="ghost" @click="scaleOpen = true">绩点分段表</UButton></div>
      <div class="grade-statistics">
        <div class="primary-stat"><span>平均绩点</span><p>{{ gpa }}<small>/ 4.00</small></p></div>
        <div><span>课程记录</span><p>{{ selected.length }}<small>门</small></p></div>
        <div><span>课程学分</span><p>{{ credits }}<small>学分</small></p></div>
      </div>
    </div>
    <div class="prototype-filters">
      <label class="term-field"><span class="sr-only">选择学期</span><select v-model="term" aria-label="选择学期"><option value="">全部学期</option><option v-for="label in terms" :key="label" :value="label">{{ label }}</option></select></label>
      <label class="search-field"><UIcon name="i-lucide-search" aria-hidden="true" /><input v-model="search" type="search" placeholder="搜索课程" aria-label="搜索演示课程"></label>
      <span class="result-count">{{ filtered.length }} 条成绩</span>
    </div>
    <div v-for="group in groups" :key="group.label" class="semester-group">
      <div class="semester-heading"><h3>{{ group.label }}</h3></div>
      <table class="desktop-grades"><caption class="sr-only">{{ group.label }}演示成绩</caption><thead><tr><th scope="col">课程</th><th scope="col">成绩</th><th scope="col">学分</th><th scope="col">绩点</th><th scope="col"><span class="sr-only">操作</span></th></tr></thead>
        <tbody><tr v-for="course in group.courses" :key="course.id">
          <td><b>{{ course.name }}</b><small>{{ course.nature }}<span v-if="course.score < 60" class="failed-label">未通过</span></small></td>
          <td><strong class="score" :class="{ failed: course.score < 60 }">{{ course.score }}</strong></td><td>{{ course.credit }}</td><td>{{ course.point.toFixed(1) }}</td>
          <td><button class="detail-button" :aria-label="`查看${course.name}详情`" @click="showDetail(course)"><UIcon name="i-lucide-chevron-right" aria-hidden="true" /></button></td>
        </tr></tbody>
      </table>
      <div class="mobile-grades"><button v-for="course in group.courses" :key="course.id" class="mobile-course" @click="showDetail(course)"><span class="mobile-course-body"><b>{{ course.name }}</b><span class="mobile-meta">{{ course.credit }} 学分 <i>·</i> 绩点 {{ course.point.toFixed(1) }} <i>·</i> {{ course.nature }}</span><span v-if="course.score < 60" class="failed-label">未通过</span></span><strong class="score" :class="{ failed: course.score < 60 }">{{ course.score }}</strong><UIcon name="i-lucide-chevron-right" aria-hidden="true" /></button></div>
    </div>
    <button v-if="filtered.length > 6" class="expand-grades" :aria-expanded="expanded" @click="expanded = !expanded"><span>{{ expanded ? '收起' : `展开其余 ${filtered.length - 6} 条` }}</span><svg class="expand-chevron" :class="{ open: expanded }" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button>
    <div v-if="!filtered.length" class="grade-empty"><UIcon name="i-lucide-search" aria-hidden="true" /><p>没有找到相关课程</p><UButton color="neutral" variant="ghost" @click="search = ''">清除搜索</UButton></div>

    <UModal v-model:open="scaleOpen" title="绩点分段表" description="来源：提供的截图" :ui="{ content: 'max-w-md', body: 'p-4 sm:p-6', footer: 'justify-end' }">
      <template #body><table class="grade-scale"><thead><tr><th scope="col">考核成绩</th><th scope="col">等级制</th><th scope="col">绩点</th></tr></thead><tbody><tr v-for="band in bands" :key="band[0]"><td>{{ band[0] }}</td><td>{{ band[1] }}</td><td>{{ band[2] }}</td></tr></tbody></table></template>
      <template #footer><UButton @click="scaleOpen = false">我知道了</UButton></template>
    </UModal>
    <UModal v-model:open="detailOpen" :title="detail?.name || '课程详情'" description="演示数据" :ui="{ content: 'max-w-md' }">
      <template #body><template v-if="detail"><div class="detail-result"><div><span>成绩</span><strong :class="{ failed: detail.score < 60 }">{{ detail.score }}</strong></div><div><span>学分</span><strong>{{ detail.credit }}</strong></div><div><span>绩点</span><strong>{{ detail.point.toFixed(1) }}</strong></div></div><dl class="grade-detail"><dt>学期</dt><dd>{{ detail.term }}</dd><dt>课程编号</dt><dd>{{ detail.id }}</dd><dt>课程性质</dt><dd>{{ detail.nature }}</dd><dt>考试性质</dt><dd>{{ detail.attempt }}</dd></dl></template></template>
    </UModal>
  </section>
</template>

<style scoped>
.grade-prototype { --grade-accent: var(--ui-primary); --grade-tint: var(--ui-bg-muted); min-width: 0; font-size: 14px; color: var(--ui-text); }
.prototype-caption, .prototype-caption > span { display: flex; align-items: center; gap: .6rem; }
.prototype-caption { justify-content: space-between; flex-wrap: wrap; gap: .6rem; margin-bottom: .6rem; font-size: 12px; color: var(--ui-text-muted); }
.prototype-caption a { color: var(--ui-text-muted); }
.grade-overview { padding: .75rem 1rem; border: 1px solid var(--ui-border); border-radius: 10px; background: var(--grade-tint); }
.overview-title { display: flex; justify-content: space-between; align-items: center; gap: 1rem; }
.grade-prototype h2 { margin: 0; font-size: 14px; line-height: 1.4; font-weight: 650; }
.grade-statistics { display: grid; grid-template-columns: 1.3fr 1fr 1fr; gap: 1rem; margin-top: .6rem; }
.grade-statistics > div + div { border-left: 1px solid var(--ui-border); padding-left: 1.5rem; }
.grade-statistics span, .detail-result span { font-size: 12px; color: var(--ui-text-muted); }
.grade-statistics p { margin: .15rem 0 0; font-size: 24px; line-height: 1.3; font-weight: 650; font-variant-numeric: tabular-nums; }
.grade-statistics .primary-stat p { color: var(--grade-accent); }
.grade-statistics small { font-size: 12px; font-weight: 400; color: var(--ui-text-muted); margin-left: .4rem; }
.prototype-filters { display: flex; align-items: center; flex-wrap: wrap; gap: .65rem; margin: .85rem 0; }
.prototype-filters select, .search-field { box-sizing: border-box; height: 34px; border: 1px solid var(--ui-border); border-radius: 6px; background: var(--ui-bg); color: var(--ui-text); font-family: inherit; font-size: 14px; }
.prototype-filters select { padding: 0 .625rem; max-width: 100%; }
.search-field { display: flex; align-items: center; gap: .4rem; padding: 0 .625rem; width: 200px; }
.search-field > span { flex: 0 0 16px; color: var(--ui-text-muted); }
.search-field input { width: 100%; min-width: 0; border: none; background: transparent; font: inherit; outline: none; }
.search-field:focus-within { outline: 2px solid var(--ui-primary); outline-offset: 2px; }
.result-count { margin-left: auto; font-size: 12px; color: var(--ui-text-muted); }
.semester-group { margin: .8rem 0; }
.semester-heading { display: flex; align-items: center; justify-content: space-between; gap: .7rem; margin-bottom: .4rem; }
.semester-heading h3 { margin: 0; font-size: 14px; font-weight: 650; }
.semester-heading > span { font-size: 12px; color: var(--ui-text-muted); white-space: nowrap; }
.desktop-grades { border-collapse: collapse; width: 100%; margin: 0; }
.desktop-grades th { padding: .6rem .8rem; font-size: 12px; font-weight: 500; color: var(--ui-text-muted); background: var(--ui-bg-elevated); text-align: left; }
.desktop-grades td { padding: .4rem .8rem; border-bottom: 1px solid var(--ui-border); }
.desktop-grades td:first-child { width: 52%; }
.desktop-grades td:last-child { width: 36px; padding-right: 0; }
.desktop-grades b, .mobile-course b { font-weight: 550; }
.desktop-grades small { display: block; margin-top: .05rem; font-size: 11px; color: var(--ui-text-muted); }
.score { font-size: 22px; font-weight: 600; font-variant-numeric: tabular-nums; color: var(--ui-text-highlighted); background: none; }
.failed, .grade-prototype .failed { color: var(--ui-error); }
.failed-label { margin-left: .5rem; font-size: 11px; color: var(--ui-error); }
.detail-button { display: grid; place-items: center; width: 34px; height: 34px; border-radius: 6px; cursor: pointer; color: var(--ui-text-muted); }
.detail-button:hover { background: var(--ui-bg-elevated); color: var(--ui-text); }
.mobile-grades { display: none; }
.grade-empty { text-align: center; padding: 2.5rem 1rem; color: var(--ui-text-muted); border: 1px dashed var(--ui-border); border-radius: 12px; }
.grade-empty p { margin: .6rem 0; }
.expand-grades { display: flex; align-items: center; justify-content: center; gap: .4rem; width: 100%; min-height: 34px; margin-top: .5rem; border-radius: 6px; color: var(--ui-text-muted); background: var(--ui-bg-muted); cursor: pointer; font-size: 13px; }
.expand-grades:hover { color: var(--ui-text); }
.expand-chevron { display: block; width: 16px; height: 16px; flex: 0 0 16px; }.expand-chevron.open { transform: rotate(180deg); }
.grade-scale { width: 100%; border-collapse: collapse; font-size: 14px; text-align: center; }
.grade-scale th, .grade-scale td { padding: .55rem .5rem; border: 1px solid var(--ui-border); font-variant-numeric: tabular-nums; }
.grade-scale th { background: var(--ui-bg-elevated); font-weight: 600; }
.detail-result { display: grid; grid-template-columns: repeat(3, 1fr); gap: .8rem; padding-bottom: 1.2rem; margin-bottom: 1.2rem; border-bottom: 1px solid var(--ui-border); }
.detail-result span, .detail-result strong { display: block; }
.detail-result strong { margin-top: .3rem; font-size: 26px; font-weight: 600; }
.grade-detail { display: grid; grid-template-columns: 5rem 1fr; gap: 1rem; font-size: 14px; }
.grade-detail dt { color: var(--ui-text-muted); }.grade-detail dd { margin: 0; }
@media (max-width: 639px) {
  .grade-overview { padding: .65rem .8rem; }
  .grade-statistics { gap: .6rem; grid-template-columns: 1.2fr .8fr 1fr; }
  .grade-statistics > div + div { padding-left: .75rem; }
  .grade-statistics p { font-size: 22px; }
  .grade-statistics small { display: block; margin: .15rem 0 0; font-size: 10px; }
  .term-field { width: 100%; }.term-field select { width: 100%; }
  .search-field { flex: 1; width: auto; }
  .desktop-grades { display: none; }.mobile-grades { display: grid; gap: .35rem; }
  .mobile-course { display: flex; align-items: center; gap: .6rem; width: 100%; padding: .6rem .75rem; border: 1px solid var(--ui-border); border-radius: 8px; background: var(--ui-bg); text-align: left; cursor: pointer; }
  .mobile-course-body { flex: 1; min-width: 0; }.mobile-course b { display: block; font-size: 14px; }
  .mobile-meta { display: block; margin-top: .15rem; font-size: 11px; color: var(--ui-text-muted); }.mobile-meta i { font-style: normal; margin: 0 .25rem; }
  .mobile-course > .score { flex: 0 0 auto; }.mobile-course > span:last-child { color: var(--ui-text-muted); flex-shrink: 0; }
  .mobile-course .failed-label { margin: .3rem 0 0; display: block; }
}
</style>
