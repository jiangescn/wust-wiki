import type { GradeCourse } from '../types/academic'

export function gradeNumber(value: string): number | null {
  const text = value.trim()
  if (!/^\d+(?:\.\d+)?$/.test(text)) return null
  const number = Number(text)
  return Number.isFinite(number) ? number : null
}

function termOrder(value: string): number | null {
  const match = value.trim().match(/^(\d{4})\s*[-–—/]\s*\d{4}\s*(?:学年)?\s*[-–—/ ]\s*(?:第)?([123一二三])(?:学期)?$/)
  if (!match) return null
  const semester = { 一: 1, 二: 2, 三: 3 }[match[2]!] ?? Number(match[2])
  return Number(match[1]) * 10 + semester
}

export function groupGradeAttempts(courses: GradeCourse[]) {
  const groups = new Map<string, { key: string; records: GradeCourse[]; latest: number | null }>()
  courses.forEach((course, index) => {
    // Names alone cannot distinguish different courses with the same title.
    const key = course.code.trim() ? `code:${course.code.trim()}` : `row:${index}`
    const group = groups.get(key) ?? { key, records: [], latest: null }
    group.records.push(course)
    groups.set(key, group)
  })
  for (const group of groups.values()) {
    if (group.records.length === 1) { group.latest = 0; continue }
    const dates = group.records.map(course => {
      const makeup = course.makeupTerm?.trim() || ''
      return makeup && !/^[-—–/]+$/.test(makeup) ? termOrder(makeup) : termOrder(course.term)
    })
    if (dates.some(date => date === null)) continue
    const newest = Math.max(...dates as number[])
    let candidates = group.records.map((_, i) => i).filter(i => dates[i] === newest)
    // Within the same term, a marked repeat/makeup follows the normal attempt.
    const repeats = candidates.filter(i => /重修|补考|补修/.test(group.records[i]!.attempt))
    if (repeats.length) candidates = repeats
    if (candidates.length === 1 || candidates.every(i => JSON.stringify(group.records[i]) === JSON.stringify(group.records[candidates[0]!]))) group.latest = candidates[0]!
  }
  return [...groups.values()]
}

export function calculateGpa(courses: GradeCourse[]) {
  let credits = 0, weighted = 0, count = 0, skipped = 0
  for (const course of courses) {
    const credit = gradeNumber(course.credit), point = gradeNumber(course.point)
    if (credit === null || credit <= 0 || point === null) { skipped++; continue }
    credits += credit; weighted += credit * point; count++
  }
  return { credits, count, skipped, gpa: credits > 0 ? weighted / credits : null }
}
