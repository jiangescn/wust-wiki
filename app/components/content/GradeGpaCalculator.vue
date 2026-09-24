<script setup lang="ts">
import type { GradeCourse } from '~/types/academic'
import WikiMotion from '../WikiMotion.vue'
import { calculateGpa, groupGradeAttempts, gradeNumber } from '~/utils/gpa'
const props = defineProps<{ courses: GradeCourse[] }>()
const groups = computed(() => groupGradeAttempts(props.courses))
const choices = ref<Record<string, number | ''>>({})
const included = ref<Record<string, boolean>>({})
const detailsOpen = ref(false)
const calculated = ref(false)
watch(() => props.courses, () => {
  choices.value = Object.fromEntries(groups.value.map(group => [group.key, group.latest ?? '']))
  included.value = Object.fromEntries(groups.value.map(group => [group.key, true]))
  calculated.value = false
}, { immediate: true })
watch([choices, included], () => { calculated.value = false }, { deep: true })
const chosen = computed(() => groups.value.flatMap(group => {
  const choice = choices.value[group.key]
  return included.value[group.key] && typeof choice === 'number' && group.records[choice] ? [group.records[choice]!] : []
}))
const unresolved = computed(() => groups.value.filter(group => included.value[group.key] && choices.value[group.key] === '').length)
const summary = computed(() => calculateGpa(chosen.value))
const semesters = computed(() => {
  const byTerm = new Map<string, typeof groups.value>()
  for (const group of groups.value) {
    const choice = choices.value[group.key]
    const course = typeof choice === 'number' ? group.records[choice]! : group.records[0]!
    const term = course.makeupTerm?.trim() && !/^[-—–/]+$/.test(course.makeupTerm.trim()) ? course.makeupTerm : course.term || '学期未提供'
    byTerm.set(term, [...(byTerm.get(term) || []), group])
  }
  return [...byTerm.entries()].sort(([a], [b]) => b.localeCompare(a, 'zh-CN', { numeric: true })).map(([term, items]) => ({ term, groups: items, selected: items.filter(group => included.value[group.key]).length }))
})
function selectSemester(keys: string[], selected: boolean) { for (const key of keys) included.value[key] = selected }
function valid(course: GradeCourse) { return (gradeNumber(course.credit) ?? 0) > 0 && gradeNumber(course.point) !== null }
function recordLabel(course: GradeCourse) { return [course.makeupTerm || course.term || '学期未提供', course.attempt, `成绩 ${course.score || '—'}`, `绩点 ${course.point || '—'}`].filter(Boolean).join(' · ') }
function calculate() { calculated.value = true; if (unresolved.value) detailsOpen.value = true }
</script>

<template>
  <section class="gpa-calculator" aria-label="绩点计算器">
    <WikiMotion>
    <div class="gpa-toolbar"><UButton :disabled="!courses.length" @click="calculate">计算绩点</UButton><button v-if="courses.length" class="gpa-settings" :aria-expanded="detailsOpen" @click="detailsOpen = !detailsOpen"><span>选择课程与成绩</span><svg class="expand-chevron" :class="{ open: detailsOpen }" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></button><span>重修按最新成绩计算</span></div>
    <p v-if="!courses.length" class="gpa-note">请先在上方查询成绩。</p>
    <div v-if="calculated && !unresolved" class="gpa-summary" aria-live="polite"><div><span>平均绩点</span><b>{{ summary.gpa === null ? '—' : summary.gpa.toFixed(2) }}</b></div><div><span>计入学分</span><b>{{ Number(summary.credits.toFixed(2)) }}</b></div><div><span>计入课程</span><b>{{ summary.count }}</b></div></div>
    <p v-if="unresolved" class="gpa-note" role="status">{{ unresolved }} 门课程需选择最新成绩。</p>
    <p v-if="calculated && summary.skipped" class="gpa-note">{{ summary.skipped }} 门缺少有效学分或绩点，未计入。</p>
    <div v-if="detailsOpen" class="gpa-courses">
      <section v-for="semester in semesters" :key="semester.term" class="gpa-semester">
      <label class="gpa-semester-heading"><input type="checkbox" :aria-label="`选择${semester.term}全部课程`" :checked="semester.selected === semester.groups.length" :indeterminate="semester.selected > 0 && semester.selected < semester.groups.length" @change="selectSemester(semester.groups.map(group => group.key), ($event.target as HTMLInputElement).checked)"><span>{{ semester.term }}</span><small>{{ semester.selected }}/{{ semester.groups.length }}</small></label>
      <div v-for="group in semester.groups" :key="group.key" class="gpa-course">
        <label><input v-model="included[group.key]" type="checkbox"><span>{{ group.records[0]!.name }}<small>{{ group.records[0]!.code }}</small></span></label>
        <select v-if="group.records.length > 1" v-model="choices[group.key]" :aria-label="`${group.records[0]!.name}采用的成绩`"><option value="" disabled>选择最新成绩</option><option v-for="(course, i) in group.records" :key="i" :value="i">{{ recordLabel(course) }}</option></select>
        <span v-else class="gpa-course-value">{{ group.records[0]!.credit || '—' }} 学分 · {{ group.records[0]!.point || '—' }} 绩点<span v-if="!valid(group.records[0]!)">（不计入）</span></span>
      </div>
      </section>
    </div>
    <p class="gpa-note">绩点计算仅供参考，请以学校通知为准。</p>
    </WikiMotion>
  </section>
</template>

<style scoped>
.gpa-calculator { border: 1px solid var(--ui-border); border-radius: 10px; padding: .8rem; color: var(--ui-text); background: var(--ui-bg); font-size: 14px; min-width: 0; }
.gpa-toolbar { display: flex; align-items: center; gap: .65rem; flex-wrap: wrap; }.gpa-toolbar > span { font-size: 12px; color: var(--ui-text-muted); }
.gpa-settings { display: inline-flex; align-items: center; gap: .35rem; min-height: 34px; font-size: 13px; line-height: 20px; color: var(--ui-primary); cursor: pointer; }
.expand-chevron { display: block; width: 16px; height: 16px; flex: 0 0 16px; }.expand-chevron.open { transform: rotate(180deg); }
.gpa-note { margin: .6rem 0 0; font-size: 12px; color: var(--ui-text-muted); }
.gpa-summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; padding: .65rem .8rem; margin-top: .75rem; border-radius: 6px; background: var(--ui-bg-muted); }
.gpa-summary span, .gpa-summary b { display: block; }.gpa-summary span { color: var(--ui-text-muted); font-size: 12px; }.gpa-summary b { font-size: 24px; font-weight: 600; font-variant-numeric: tabular-nums; }.gpa-summary > div:first-child b { color: var(--ui-primary); }
.gpa-courses { margin-top: .7rem; max-height: 360px; overflow-y: auto; }
.gpa-semester + .gpa-semester { margin-top: .65rem; }
.gpa-semester-heading { display: flex; align-items: center; gap: .5rem; padding: .5rem; border-radius: 5px; background: var(--ui-bg-muted); font-weight: 600; font-size: 13px; }
.gpa-semester-heading input { accent-color: var(--ui-primary); }.gpa-semester-heading small { margin-left: auto; font-weight: 400; color: var(--ui-text-muted); }
.gpa-course { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: .5rem; padding: .5rem 0; border-top: 1px solid var(--ui-border); }
.gpa-course label { display: flex; align-items: center; gap: .5rem; min-width: 0; }.gpa-course input { accent-color: var(--ui-primary); flex-shrink: 0; }.gpa-course small { display: block; color: var(--ui-text-muted); font-size: 11px; }
.gpa-course select { height: 34px; max-width: 100%; min-width: 0; font-size: 14px; border: 1px solid var(--ui-border); border-radius: 6px; padding: 0 .5rem; color: var(--ui-text); background: var(--ui-bg); }.gpa-course-value { font-size: 12px; color: var(--ui-text-muted); }
</style>
