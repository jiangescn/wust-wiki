import { SCHEDULE_CACHE_KEY, currentTeachingWeek, normalizeCourses, readSnapshot } from '../../app/utils/schedule.ts'

// Built into a local, script-only document at the Wiki origin inside Android WebView.
window.readToday = function (now = Date.now()) {
  const snapshot = readSnapshot(localStorage.getItem(SCHEDULE_CACHE_KEY), now)
  if (!snapshot) return { status: 'missing' }
  const week = currentTeachingWeek(snapshot.result, now)
  if (week === null) return { status: 'unknown' }
  const day = new Date(now + 8 * 3600000).getUTCDay() || 7
  const courses = normalizeCourses(snapshot.result.lessons)
  const uncertain = courses.some(c => (!c.day || c.day === day) && (!c.validTime || !c.weekNumbers))
  const rows = courses.filter(c => c.validTime && c.day === day && c.weekNumbers?.includes(week))
    .flatMap(c => c.slots.map(slot => ({ name: c.name, place: c.location, start: slot[0], end: slot.at(-1) })))
    .sort((a, b) => a.start - b.start)
  return { status: 'ready', week, uncertain, rows }
}
