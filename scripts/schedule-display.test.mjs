import test from 'node:test'
import assert from 'node:assert/strict'
import { parseWeeks, lessonSlots, normalizeCourses, layoutDay, makeSnapshot, readSnapshot, SCHEDULE_TTL, campusTimes, currentTeachingWeek } from '../app/utils/schedule.ts'

test('current teaching week follows the specified August 31 start and China-time Monday boundaries', () => {
  const term = { schoolYear: '2026-2027', semester: 1 }
  const at = date => currentTeachingWeek(term, Date.parse(date))
  assert.equal(at('2026-08-30T23:59:59+08:00'), null)
  assert.equal(at('2026-08-31T00:00:00+08:00'), 1)
  assert.equal(at('2026-09-06T15:59:59Z'), 1)
  assert.equal(at('2026-09-06T16:00:00Z'), 2)
  assert.equal(at('2026-09-24T00:00:00+08:00'), 4)
  assert.equal(at('2027-08-31T00:00:00+08:00'), null)
  assert.equal(currentTeachingWeek({ schoolYear: '2025-2026', semester: 1 }, Date.parse('2026-09-24')), null)
  assert.equal(currentTeachingWeek({ ...term, semester: 2 }, Date.parse('2027-03-01')), null)
})

test('teaching weeks parse sparse ranges and parity, unknown rules stay unknown', () => {
  assert.deepEqual(parseWeeks('2,4-5'), [2, 4, 5])
  assert.deepEqual(parseWeeks('1-8单(周)'), [1, 3, 5, 7])
  assert.deepEqual(parseWeeks('2–10（双周）'), [2, 4, 6, 8, 10])
  assert.deepEqual(parseWeeks('第4周'), null)
  for (const text of ['3-1', '1-999999', '每周', '', '1,3补课', '0-4']) assert.equal(parseWeeks(text), null)
})
test('nonconsecutive sections never cover intervening empty classes', () => {
  assert.deepEqual(lessonSlots({ sections: '01-02,4,7-8', start: 1, end: 8 }), [[1, 2], [4], [7, 8]])
  assert.deepEqual(lessonSlots({ start: 3, length: 2 }), [[3, 4]])
  assert.equal(lessonSlots({ sections: '未知', start: 1, end: 2 }), null)
})
test('overlap lanes keep every class and later independent classes reclaim full width', () => {
  const lessons = [{name:'A',day:1,sections:'1-2',weeks:'1-4'}, {name:'B',day:1,sections:'2-3',weeks:'1-4'}, {name:'C',day:1,sections:'5-6',weeks:'1-4'}]
  const blocks = layoutDay(normalizeCourses(lessons))
  assert.deepEqual(blocks.map(b => [b.lane, b.lanes]), [[0,2],[1,2],[0,1]])
  const unknown = normalizeCourses([{name:'未知',day:8,sections:'1-2',weeks:'校方另行安排'}])[0]
  assert.equal(unknown.validTime, false)
  assert.equal(unknown.weekNumbers, null)
  assert.equal(normalizeCourses([{name:'A'},{name:'A'}])[0].color, normalizeCourses([{name:'A'},{name:'A'}])[1].color)
})
test('campus timetable preserves supplied morning differences and never invents section 11', () => {
  assert.deepEqual(campusTimes.huangjiahu[0], ['08:20','09:05'])
  assert.deepEqual(campusTimes.qingshan[0], ['08:00','08:45'])
  assert.deepEqual(campusTimes.huangjiahu.slice(4), campusTimes.qingshan.slice(4))
  assert.equal(campusTimes.huangjiahu[10], undefined)
})

test('different courses get unique colors beyond six, independent of response order', () => {
  const lessons = Array.from({ length: 40 }, (_, i) => ({ name: `课程 ${i}` }))
  const courses = normalizeCourses([...lessons, { name: '课程 0' }, { name: ' 课程 0 ' }])
  assert.equal(new Set(courses.slice(0, 40).map(course => course.color)).size, 40)
  assert.equal(courses[0].color, courses[40].color)
  assert.equal(courses[0].color, courses[41].color)
  const reversed = new Map(normalizeCourses([...lessons].reverse()).map(course => [course.name, course.color]))
  for (const course of courses.slice(0, 40)) assert.equal(course.color, reversed.get(course.name))
})
test('seven-day cache projects course fields, never credentials, and expires at fixed boundary', () => {
  const now = 1000000000
  const snapshot = makeSnapshot({ provider:'wust', schoolYear:'2026-2027', semester:1, sessionToken:'SECRET', cookie:'SECRET', lessons:[{name:'测试课',teacher:'测试教师',location:'测试教室',day:1,sections:'1-2',weeks:'1-16',password:'SECRET'}], notes:['测试备注'] }, now)
  assert.doesNotMatch(JSON.stringify(snapshot), /SECRET|password|cookie|sessionToken/)
  assert.equal(readSnapshot(JSON.stringify(snapshot), now + SCHEDULE_TTL - 1).fetchedAt, now)
  assert.equal(readSnapshot(JSON.stringify(snapshot), now + SCHEDULE_TTL), null)
  assert.equal(readSnapshot(JSON.stringify(snapshot), now - 1), null)
  assert.equal(readSnapshot(JSON.stringify({...snapshot, expiresAt:snapshot.expiresAt+1}), now), null)
  assert.equal(readSnapshot('{broken', now), null)
  assert.equal(makeSnapshot({provider:'wust',lessons:[null]}, now), null)
  assert.equal(makeSnapshot({provider:'wust',lessons:[]}, now).result.lessons.length, 0)
})
