<script setup lang="ts">
import WikiMotion from '../WikiMotion.vue'
import { campusTimes, weekdays, normalizeCourses, layoutDay, currentTeachingWeek, type Campus, type Course, type ScheduleResult } from '~/utils/schedule'
const props = withDefaults(defineProps<{ result: ScheduleResult; demo?: boolean }>(), { demo: false })
const campus = ref<Campus>('huangjiahu')
const now = useNow({ interval: 60_000 })
const currentWeek = computed(() => props.demo ? null : currentTeachingWeek(props.result, now.value.getTime()))
const week = ref(props.demo ? 4 : currentWeek.value ?? 0)
const mode = ref<'week' | 'day'>('day')
const day = ref(1)
const detail = ref<Course>()
const detailOpen = ref(false)
const courses = computed(() => normalizeCourses(props.result.lessons))
const maxWeek = computed(() => Math.max(1, currentWeek.value ?? 0, ...courses.value.flatMap(course => course.weekNumbers || [])))
const visible = computed(() => courses.value.filter(course => course.validTime && (week.value === 0 || course.weekNumbers?.includes(week.value))))
const unplaced = computed(() => courses.value.filter(course => !course.validTime || (week.value !== 0 && course.weekNumbers === null)))
const dayCourses = computed(() => visible.value.filter(course => course.day === day.value).sort((a, b) => a.slots[0]![0]! - b.slots[0]![0]!))
const sectionCount = computed(() => Math.max(10, ...visible.value.flatMap(course => course.slots.flat())))
const grids = computed(() => weekdays.map((_, index) => layoutDay(visible.value.filter(course => course.day === index + 1))))
const gridColumns = computed(() => '64px ' + grids.value.map(blocks => `minmax(${92 * Math.max(1, ...blocks.map(block => block.lanes))}px, 1fr)`).join(' '))
function timing(section: number) { return campusTimes[campus.value][section - 1] }
function sectionLabel(course: Course) { return course.slots.length ? course.slots.map(slots => slots.length === 1 ? slots[0] : slots[0] + '–' + slots.at(-1)).join('、') : course.sections || '待确认' }
function courseTime(course: Course) {
  return course.slots.length ? course.slots.map(slots => {
    const start = timing(slots[0]!)?.[0], end = timing(slots.at(-1)!)?.[1]
    return start && end ? start + '–' + end : '时间待补充'
  }).join(' / ') : '待确认'
}
function openDetail(course: Course) { detail.value = course; detailOpen.value = true }
function changeWeek(delta: number) { week.value = Math.max(1, Math.min(maxWeek.value, week.value + delta)) }
watch(() => props.result, () => { week.value = props.demo ? 4 : currentWeek.value ?? 0; detailOpen.value = false })
watch(currentWeek, (value, previous) => { if (week.value === previous) week.value = value ?? 0 })
onMounted(() => {
  day.value = new Date().getDay() || 7
  if (props.demo) { week.value = 4; day.value = 1 }
  if (!window.matchMedia('(max-width: 639px)').matches) mode.value = 'week'
})
</script>

<template>
  <section class="schedule-board" aria-label="学校课表">
    <div class="board-heading">
      <div><h3>{{ demo ? "课表样例" : "我的课表" }}</h3><p>{{ demo ? "虚构课程 · 仅用于预览排版" : [result.schoolYear ? result.schoolYear + " 学年" : "当前学期", result.semester ? "第 " + result.semester + " 学期" : ""].filter(Boolean).join(" · ") }}</p></div>
      <label class="campus-select">作息校区<select v-model="campus" aria-label="作息校区"><option value="huangjiahu">黄家湖校区</option><option value="qingshan">青山校区</option></select></label>
    </div>
    <div class="toolbar">
      <div class="week-switch">
        <UButton color="neutral" variant="ghost" aria-label="上一周" :disabled="week <= 1" @click="changeWeek(-1)">‹</UButton>
        <select v-model.number="week" aria-label="教学周"><option :value="0">全部课程</option><option v-for="w in maxWeek" :key="w" :value="w">第 {{ w }} 周{{ w === currentWeek ? " · 本周" : "" }}</option></select>
        <UButton color="neutral" variant="ghost" aria-label="下一周" :disabled="week >= maxWeek" @click="changeWeek(1)">›</UButton>
      </div>
      <UButton v-if="currentWeek && week !== currentWeek" color="neutral" variant="ghost" @click="week = currentWeek">本周</UButton>
      <span class="course-count">{{ visible.length }} 条排课</span>
      <div class="view-switch" role="group" aria-label="课表视图"><button :aria-pressed="mode === 'week'" @click="mode = 'week'">周课表</button><button :aria-pressed="mode === 'day'" @click="mode = 'day'">按日列表</button></div>
    </div>
    <WikiMotion :resize="false" :change-key="[mode, week, day, campus].join('-')">
    <template v-if="mode === 'week'">
      <p class="mobile-hint">左右滑动查看整周</p>
      <div class="grid-scroll" tabindex="0" role="region" aria-label="一周课表，可横向滚动">
        <div class="week-grid" :style="{ '--sections': sectionCount, gridTemplateColumns: gridColumns }">
          <div class="time-column"><div class="day-heading">节次</div><div v-for="n in sectionCount" :key="n" class="time-cell" :class="{ 'session-start': n === 5 || n === 9 }"><b>{{ String(n).padStart(2, '0') }}</b><span v-if="timing(n)">{{ timing(n)?.[0] }}<br>{{ timing(n)?.[1] }}</span><span v-else>待补充</span></div></div>
          <div v-for="(grid, index) in grids" :key="index" class="day-column">
            <div class="day-heading" :class="{ weekend: index > 4 }">{{ weekdays[index] }}</div>
            <div class="day-grid" >
              <div v-for="n in sectionCount" :key="`cell-${n}`" class="grid-cell" :class="{ 'session-start': n === 5 || n === 9 }" :style="{ gridRow: n, gridColumn: '1 / -1' }" aria-hidden="true" />
              <button v-for="block in grid" :key="`${block.course.id}-${block.start}`" class="course-card" :class="{ compact: block.start === block.end }" :style="{ '--course-hue': block.course.color, gridRow: `${block.start} / ${block.end + 1}`, gridColumn: 1, width: `calc(${100 / block.lanes}% - 6px)`, marginLeft: `calc(${100 * block.lane / block.lanes}% + 3px)` }" :aria-label="`${block.course.name}，${weekdays[index]}，第${sectionLabel(block.course)}节，查看详情`" @click="openDetail(block.course)"><strong>{{ block.course.name }}</strong><span>{{ block.course.location || "未提供地点" }}</span><small>{{ block.course.weeks || "周次待确认" }}</small></button>
            </div>
          </div>
        </div>
      </div>
    </template>
    <template v-else>
      <div class="day-switch" role="group" aria-label="选择星期"><button v-for="(label, index) in weekdays" :key="label" :aria-pressed="day === index + 1" @click="day = index + 1"><span>{{ label }}</span><small>{{ visible.filter(course => course.day === index + 1).length }} 门</small></button></div>
      <div class="agenda">
        <button v-for="course in dayCourses" :key="course.id" class="agenda-card" :style="{ '--course-hue': course.color }" @click="openDetail(course)"><span class="agenda-time"><b>{{ sectionLabel(course) }} 节</b><small>{{ courseTime(course) }}</small></span><span class="agenda-body"><strong>{{ course.name }}</strong><span>{{ course.location || "未提供地点" }}</span><small>{{ course.weeks || "周次待确认" }}</small></span><span aria-hidden="true">↗</span></button>
        <div v-if="!dayCourses.length" class="empty-day">这一天没有安排课程<span>{{ week ? `第 ${week} 周` : "全部课程" }} · {{ weekdays[day - 1] }}</span></div>
      </div>
    </template>
    </WikiMotion>
    <div v-if="unplaced.length" class="schedule-notes"><h4>时间或周次待确认（{{ unplaced.length }} 条）</h4><button v-for="course in unplaced" :key="course.id" class="unplaced-course" @click="openDetail(course)">{{ course.name }} · {{ course.weeks || '未提供周次' }} · {{ course.sections || '未提供节次' }} ↗</button></div>
    <details v-if="result.notes?.length" class="schedule-notes"><summary>教务备注 <span>{{ result.notes.length }}</span></summary><ul><li v-for="(note, index) in result.notes" :key="index">{{ note }}</li></ul></details>
    <UModal v-model:open="detailOpen" :title="detail?.name || '课程详情'" :description="demo ? '虚构课程' : '课程详情'">
      <template #body><dl v-if="detail" class="course-details"><dt>教师</dt><dd>{{ detail.teacher || "未提供" }}</dd><dt>地点</dt><dd>{{ detail.location || "未提供" }}</dd><dt>上课安排</dt><dd>{{ detail.day ? weekdays[detail.day - 1] : "星期待确认" }} · 第 {{ sectionLabel(detail) }} 节</dd><dt>对应时间</dt><dd>{{ courseTime(detail) }}</dd><dt>教学周</dt><dd>{{ detail.weeks || "未提供" }}</dd><dt>作息校区</dt><dd>{{ campus === 'huangjiahu' ? '黄家湖校区' : '青山校区' }}</dd></dl></template>
    </UModal>
  </section>
</template>

<style scoped>
.schedule-board { --slot-height: 66px; border: 1px solid var(--ui-border); border-radius: 16px; background: var(--ui-bg); overflow: hidden; min-width: 0; margin-bottom: 2rem; }
.board-heading { display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap; padding: 1.4rem 1.25rem 1rem; }
.board-heading h3 { font-size: 1.3rem; margin: .35rem 0 !important; font-weight: 700; }
.board-heading p { color: var(--ui-text-muted); font-size: .8rem; margin: 0; }
.campus-select { font-size: .7rem; color: var(--ui-text-muted); display: flex; flex-direction: column; gap: .3rem; }
select { box-sizing: border-box; height: 2.125rem; border: 1px solid var(--ui-border); background: var(--ui-bg); color: var(--ui-text); border-radius: 6px; padding: 0 .625rem; font-family: inherit; font-size: .875rem; line-height: 1.25rem; }
.toolbar { display: flex; gap: .75rem; align-items: center; flex-wrap: wrap; padding: 0 1.25rem 1rem; }
.week-switch { display: flex; align-items: center; gap: .2rem; }
.week-switch select { font-weight: 650; border: none; }
.week-switch button { font-size: 1.3rem; padding: .1rem .6rem; }
.course-count { font-size: .75rem; color: var(--ui-text-muted); }
.view-switch { display: flex; margin-left: auto; background: var(--ui-bg-elevated); border-radius: 8px; padding: 3px; }
.view-switch button { padding: .35rem .7rem; font-size: .8rem; border-radius: 6px; cursor: pointer; }
.view-switch button[aria-pressed=true] { background: var(--ui-bg); color: var(--ui-primary); box-shadow: 0 1px 4px #00000012; }
.grid-scroll { overflow: auto; max-width: 100%; border-block: 1px solid var(--ui-border); }
.week-grid { display: grid; grid-template-columns: 64px repeat(7, minmax(92px, 1fr)); min-width: 708px; }
.time-column { position: sticky; left: 0; z-index: 2; background: var(--ui-bg); box-shadow: 1px 0 var(--ui-border); }
.day-heading { height: 40px; display: flex; align-items: center; justify-content: center; font-size: .75rem; font-weight: 650; background: var(--ui-bg-muted); border-bottom: 1px solid var(--ui-border); }
.day-heading.weekend { color: var(--ui-text-muted); }
.time-cell { height: var(--slot-height); display: flex; flex-direction: column; align-items: center; justify-content: center; line-height: 1.25; border-bottom: 1px solid var(--ui-border); }
.time-cell b { font-size: .8rem; }
.time-cell span { color: var(--ui-text-muted); font-size: .62rem; margin-top: 3px; font-variant-numeric: tabular-nums; }
.day-grid { display: grid; grid-template-columns: minmax(0, 1fr); grid-template-rows: repeat(var(--sections), var(--slot-height)); }
.grid-cell { border-right: 1px solid var(--ui-border); border-bottom: 1px solid var(--ui-border); }
.session-start { border-top: 2px solid var(--ui-border-accented); }
.course-card { z-index: 1; margin: 3px; padding: .5rem .4rem; border-radius: 8px; border-left: 3px solid var(--course-color); background: var(--course-bg); color: var(--course-text); text-align: left; display: flex; flex-direction: column; gap: .3rem; min-width: 0; overflow: hidden; cursor: pointer; transition: filter .15s; }
.course-card:hover, .agenda-card:hover { filter: brightness(.96); }
.course-card strong { font-size: .78rem; line-height: 1.45; font-weight: 650; }
.course-card span { font-size: .65rem; line-height: 1.35; }
.course-card small { font-size: .6rem; opacity: .8; margin-top: auto; }
.course-card, .agenda-card { --course-color: hsl(var(--course-hue) 48% 44%); --course-bg: hsl(var(--course-hue) 60% 94%); --course-text: hsl(var(--course-hue) 45% 27%); }
:global(.dark .schedule-board .course-card), :global(.dark .schedule-board .agenda-card) { --course-color: hsl(var(--course-hue) 48% 58%); --course-bg: hsl(var(--course-hue) 24% 20%); --course-text: hsl(var(--course-hue) 60% 82%); }
.schedule-board strong { background: none; }
.schedule-notes { margin: 0 1.25rem; padding: .8rem 0; border-top: 1px solid var(--ui-border); font-size: .8rem; }
.schedule-notes summary { cursor: pointer; }
.schedule-notes summary span { color: var(--ui-text-muted); margin-left: .4rem; }
.schedule-notes ul { padding-left: 1.2rem; }
.day-switch { display: grid; grid-template-columns: repeat(7, 1fr); padding: 0 1rem 1rem; gap: 3px; }
.day-switch button { display: flex; flex-direction: column; align-items: center; gap: .3rem; padding: .6rem 0; border-radius: 9px; cursor: pointer; font-size: .75rem; }
.day-switch button small { font-size: .65rem; color: var(--ui-text-muted); }
.day-switch button[aria-pressed=true] { background: var(--ui-bg-elevated); color: var(--ui-primary); box-shadow: inset 0 0 0 1px var(--ui-border); }
.agenda { padding: 0 1rem 1rem; display: grid; gap: .65rem; }
.agenda-card { display: flex; gap: 1rem; align-items: center; width: 100%; text-align: left; padding: 1rem; border-radius: 10px; background: var(--course-bg); color: var(--course-text); border-left: 3px solid var(--course-color); cursor: pointer; }
.agenda-time, .agenda-body { display: flex; flex-direction: column; gap: .35rem; }
.agenda-time { flex: 0 0 95px; font-size: .8rem; }
.agenda-time small { font-size: .65rem; }
.agenda-body { flex: 1; font-size: .9rem; }
.agenda-body span, .agenda-body small { font-size: .75rem; }
.empty-day { text-align: center; padding: 3rem 1rem; color: var(--ui-text-muted); font-size: .9rem; }
.empty-day span { display: block; font-size: .75rem; margin-top: .5rem; }
.course-details { display: grid; grid-template-columns: 5rem 1fr; gap: 1rem; font-size: .9rem; }
.course-details dt { color: var(--ui-text-muted); }
.course-details dd { margin: 0; }
button:focus-visible, select:focus-visible, .grid-scroll:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 2px; }
.mobile-hint { display: none; }
.course-card.compact small { display: none; }
.course-card.compact strong { font-size: .72rem; }
.course-card strong { overflow-wrap: anywhere; }
.unplaced-course { display: block; text-align: left; margin: .5rem 0; color: var(--ui-primary); cursor: pointer; }
@media (max-width: 639px) {
  .board-heading, .toolbar { padding-inline: 1rem; }
  .board-heading h3 { font-size: 1.1rem; }
  .board-heading { align-items: flex-start; }
  .campus-select { width: 100%; flex-direction: row; align-items: center; justify-content: space-between; }
  .toolbar { gap: .5rem; }
  .view-switch { width: 100%; margin: .2rem 0 0; }
  .view-switch button { flex: 1; }
  .mobile-hint { display: block; margin: 0; padding: 0 1rem .75rem; font-size: .7rem; color: var(--ui-text-muted); }
  .agenda-card { gap: .65rem; padding: .8rem; }
  .agenda-time { flex-basis: 72px; }
}
</style>
