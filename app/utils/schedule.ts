export type ScheduleLesson = { name: string; teacher: string; location: string; day?: number; start?: number; end?: number; length?: number; sections?: string; weeks?: string; group?: string }
export type ScheduleResult = { provider: 'wust'; schoolYear?: string; semester?: number; lessons: ScheduleLesson[]; notes?: string[] }
export type ScheduleSnapshot = { version: 1; fetchedAt: number; expiresAt: number; result: ScheduleResult }
export const SCHEDULE_CACHE_KEY = 'wust-wiki:schedule:v1'
export const SCHEDULE_TTL = 7 * 24 * 60 * 60 * 1000
export const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
export const afternoon = [['14:00', '14:45'], ['14:55', '15:40'], ['16:00', '16:45'], ['16:55', '17:40'], ['18:40', '19:25'], ['19:35', '20:20']]
// User-supplied classroom timetable, 2026-09-23; no verified times beyond section 10.
export const campusTimes = {
  huangjiahu: [['08:20', '09:05'], ['09:15', '10:00'], ['10:20', '11:05'], ['11:15', '12:00'], ...afternoon],
  qingshan: [['08:00', '08:45'], ['08:55', '09:40'], ['10:10', '10:55'], ['11:05', '11:50'], ...afternoon],
}
export type Campus = keyof typeof campusTimes

// User-defined calendar: 2026-2027 autumn term starts Monday, 2026-08-31 (China time).
export function currentTeachingWeek(result: Pick<ScheduleResult, 'schoolYear' | 'semester'>, now = Date.now()): number | null {
  if (result.schoolYear && result.schoolYear !== '2026-2027') return null
  if (result.semester && result.semester !== 1) return null
  const start = Date.parse('2026-08-31T00:00:00+08:00')
  if (now < start || now >= Date.parse('2027-08-31T00:00:00+08:00') || !Number.isFinite(now)) return null
  return Math.floor((now - start) / (7 * 24 * 60 * 60 * 1000)) + 1
}

/** null means unknown, never silently interpret unknown rules as no classes. */
export function parseWeeks(source?: string): number[] | null {
  if (!source || source.length > 300) return null
  let text = source.replace(/\s/g, '').replace(/[（]/g, '(').replace(/[）]/g, ')').replace(/[，、]/g, ',').replace(/[–—~～至]/g, '-')
  text = text.replace(/周/g, '').replace(/[()]/g, '')
  let parity: '单' | '双' | undefined
  if (/[单双]$/.test(text)) { parity = text.at(-1) as '单' | '双'; text = text.slice(0, -1) }
  const values = parseRanges(text, 60)
  return values?.filter(value => !parity || value % 2 === (parity === '单' ? 1 : 0)) ?? null
}
function parseRanges(text: string, limit: number): number[] | null {
  if (!/^\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$/.test(text)) return null
  const values = new Set<number>()
  for (const part of text.split(',')) {
    const [start = 0, end = start] = part.split('-').map(Number)
    if (start < 1 || end < start || end > limit) return null
    for (let value = start; value <= end; value++) values.add(value)
  }
  return [...values].sort((a, b) => a - b)
}
export function lessonSlots(lesson: ScheduleLesson): number[][] | null {
  const text = lesson.sections !== undefined ? lesson.sections.replace(/\s/g, '').replace(/[，、]/g, ',').replace(/[–—]/g, '-') : `${lesson.start ?? ''}-${lesson.end ?? (lesson.start ? lesson.start + (lesson.length ?? 1) - 1 : '')}`
  const values = parseRanges(text, 30)
  if (!values?.length) return null
  const slots: number[][] = []
  for (const value of values) {
    const previous = slots.at(-1)
    if (previous && previous.at(-1)! + 1 === value) previous.push(value)
    else slots.push([value])
  }
  return slots
}
export type Course = ScheduleLesson & { id: string; slots: number[][]; weekNumbers: number[] | null; color: string; validTime: boolean }
export function normalizeCourses(lessons: ScheduleLesson[]): Course[] {
  const colors = ['blue', 'purple', 'teal', 'amber', 'rose', 'lime']
  return lessons.map((lesson, index) => {
    let hash = 0
    for (const char of lesson.name) hash = (Math.imul(hash, 31) + char.charCodeAt(0)) >>> 0
    const slots = lessonSlots(lesson)
    return { ...lesson, id: `course-${index}`, slots: slots || [], weekNumbers: parseWeeks(lesson.weeks), color: colors[hash % colors.length]!, validTime: Boolean(slots && Number.isInteger(lesson.day) && lesson.day! >= 1 && lesson.day! <= 7) }
  })
}
export type CourseBlock = { course: Course; start: number; end: number; lane: number; lanes: number }
/** Only courses in the same connected overlap group share width. */
export function layoutDay(courses: Course[]): CourseBlock[] {
  const blocks: CourseBlock[] = courses.flatMap(course => course.slots.map(slots => ({ course, start: slots[0]!, end: slots.at(-1)!, lane: 0, lanes: 1 }))).sort((a, b) => a.start - b.start || b.end - a.end)
  let group: CourseBlock[] = [], ends: number[] = [], until = 0
  const finish = () => { for (const block of group) block.lanes = ends.length }
  for (const block of blocks) {
    if (block.start > until) { finish(); group = []; ends = [] }
    let lane = ends.findIndex(end => end < block.start)
    if (lane === -1) lane = ends.length
    ends[lane] = block.end; block.lane = lane; group.push(block); until = Math.max(...ends)
  }
  finish()
  return blocks
}
const string = (value: unknown, max = 500): string => typeof value === 'string' ? value.slice(0, max) : ''
/** Strict projection: neither API sessionToken nor extra credential fields enter storage. */
export function cleanSchedule(input: unknown): ScheduleResult | null {
  if (!input || typeof input !== 'object') return null
  const data = input as Record<string, unknown>
  if (data.provider !== 'wust' || !Array.isArray(data.lessons) || data.lessons.length > 2000) return null
  const lessons: ScheduleLesson[] = []
  for (const value of data.lessons) {
    if (!value || typeof value !== 'object' || typeof value.name !== 'string') return null
    const lesson: ScheduleLesson = { name: string(value.name), teacher: string(value.teacher), location: string(value.location) }
    for (const key of ['day', 'start', 'end', 'length'] as const) if (Number.isInteger(value[key]) && value[key] >= 1 && value[key] <= 60) lesson[key] = value[key]
    for (const key of ['sections', 'weeks', 'group'] as const) if (typeof value[key] === 'string') lesson[key] = string(value[key])
    lessons.push(lesson)
  }
  return { provider: 'wust', schoolYear: string(data.schoolYear, 20), semester: data.semester === 1 || data.semester === 2 ? data.semester : undefined, lessons, notes: Array.isArray(data.notes) ? data.notes.filter((n): n is string => typeof n === 'string').slice(0, 200).map(n => string(n, 2000)) : [] }
}
export function makeSnapshot(result: unknown, now = Date.now()): ScheduleSnapshot | null {
  const clean = cleanSchedule(result)
  return clean ? { version: 1, fetchedAt: now, expiresAt: now + SCHEDULE_TTL, result: clean } : null
}
export function readSnapshot(raw: string | null, now = Date.now()): ScheduleSnapshot | null {
  try {
    if (!raw || raw.length > 2_000_000) return null
    const data = JSON.parse(raw)
    if (data.version !== 1 || !Number.isFinite(data.fetchedAt) || data.fetchedAt > now || data.expiresAt !== data.fetchedAt + SCHEDULE_TTL || now >= data.expiresAt) return null
    return makeSnapshot(data.result, data.fetchedAt)
  } catch { return null }
}
