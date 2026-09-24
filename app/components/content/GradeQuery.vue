<script setup lang="ts">
import type { AcademicView, GradeResult } from '~/types/academic'
import GradeDisplayPrototype from './GradeDisplayPrototype.vue'
import GradeGpaCalculator from './GradeGpaCalculator.vue'
const props = defineProps<{ calculatorOnly?: boolean }>()
const route = useRoute()
const result = useState<GradeResult | null>('academic-grades-page', () => null)
onBeforeUnmount(() => { if (!props.calculatorOnly) result.value = null })
const term = ref(''), search = ref(''), expanded = ref(false)
watch([term, search], () => { expanded.value = false })
const terms = computed(() => [...new Set(result.value?.courses.map(c => c.term).filter(Boolean) || [])].sort().reverse())
const courses = computed(() => (result.value?.courses || []).filter(c => (!term.value || c.term === term.value) && (!search.value.trim() || `${c.name} ${c.code}`.toLowerCase().includes(search.value.trim().toLowerCase()))))
const visibleCourses = computed(() => expanded.value ? courses.value : courses.value.slice(0, 6))
function accept(data: AcademicView) { if (data.result && 'courses' in data.result) { result.value = data.result; term.value = ''; expanded.value = false } }
function clear() { result.value = null; term.value = ''; search.value = ''; expanded.value = false }
</script>
<template>
  <ClientOnly>
    <GradeGpaCalculator v-if="calculatorOnly" :courses="route.query.grades === 'sample' ? [] : result?.courses || []" />
    <GradeDisplayPrototype v-else-if="route.query.grades === 'sample'" />
    <div v-else class="grade-query">
      <SchoolAcademicQuery resource="grades" :has-result="!!result" @result="accept" @logout="clear" />
      <template v-if="result">
        <div class="grade-filters">
          <label>学期 <select v-model="term" aria-label="成绩学期"><option value="">全部学期</option><option v-for="value in terms" :key="value" :value="value">{{ value }}</option></select></label>
          <input v-model="search" aria-label="搜索课程" placeholder="搜索课程名称或编号" type="search">
          <span>{{ courses.length }} 条成绩</span>
        </div>
        <div v-if="courses.length" class="grade-scroll" role="region" aria-label="课程成绩表" tabindex="0">
          <table class="grade-table">
            <thead><tr><th>课程</th><th>成绩</th><th>学分</th><th>绩点</th><th>学期</th><th>性质 / 考核</th><th>备注</th></tr></thead>
            <tbody><tr v-for="(course, index) in visibleCourses" :key="`${course.code}-${course.term}-${index}`">
              <td><strong>{{ course.name }}</strong><small>{{ [course.code, course.group].filter(Boolean).join(' · ') }}</small></td><td class="grade-score">{{ course.score || '—' }}</td><td>{{ course.credit || '—' }}</td><td>{{ course.point || '—' }}</td><td>{{ course.term || '—' }}<small v-if="course.makeupTerm">补重：{{ course.makeupTerm }}</small></td><td>{{ [course.nature, course.assessment, course.attempt].filter(Boolean).join(' · ') || '—' }}</td><td>{{ course.mark || '—' }}</td>
            </tr></tbody>
          </table>
        </div>
        <p v-else>{{ result.courses.length ? '没有匹配的课程。' : '教务系统暂无成绩记录。' }}</p>
        <button v-if="courses.length > 6" class="expand-grades" :aria-expanded="expanded" @click="expanded = !expanded"><span>{{ expanded ? '收起' : `展开其余 ${courses.length - 6} 条` }}</span><svg class="expand-chevron" :class="{ open: expanded }" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button>
      </template>
    </div>
    <template #fallback><p>正在加载成绩查询…</p></template>
  </ClientOnly>
</template>
<style scoped>
.grade-query { min-width: 0; max-width: 100%; }
.grade-filters { display: flex; flex-wrap: wrap; align-items: center; gap: .6rem; margin: .75rem 0 .5rem; }
.grade-filters input, .grade-filters select { box-sizing: border-box; height: 2.125rem; border: 1px solid var(--ui-border); border-radius: 6px; padding: 0 .625rem; font-family: inherit; font-size: .875rem; line-height: 1.25rem; color: var(--ui-text); background: var(--ui-bg); max-width: 100%; }
.grade-filters label { display: flex; align-items: center; gap: .4rem; font-size: .875rem; }
.grade-filters span { font-size: .8rem; color: var(--ui-text-muted); }
.grade-scroll { overflow-x: auto; border: 1px solid var(--ui-border); border-radius: 10px; }
.grade-table { width: 100%; margin: 0; border-collapse: collapse; font-size: .85rem; text-align: left; }
.grade-table th, .grade-table td { padding: .45rem .65rem; border-bottom: 1px solid var(--ui-border); min-width: 4rem; }
.grade-table th { white-space: nowrap; background: var(--ui-bg-elevated); }
.grade-table td:first-child { min-width: 11rem; }.grade-table td:nth-child(5) { white-space: nowrap; }
.grade-table strong { background: none; font-weight: 600; }.grade-table small { display: block; color: var(--ui-text-muted); }
.grade-score { font-weight: 650; font-variant-numeric: tabular-nums; }
.expand-grades { display: flex; align-items: center; justify-content: center; gap: .4rem; width: 100%; min-height: 34px; margin-top: .5rem; border-radius: 6px; background: var(--ui-bg-muted); color: var(--ui-text-muted); font-size: 13px; line-height: 20px; cursor: pointer; }
.expand-chevron { display: block; width: 16px; height: 16px; flex: 0 0 16px; }.expand-chevron.open { transform: rotate(180deg); }
</style>
