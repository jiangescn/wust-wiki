import test from 'node:test'
import assert from 'node:assert/strict'
import { groupGradeAttempts, calculateGpa } from '../app/utils/gpa.ts'

const course = (overrides = {}) => ({ code: 'MATH', name: '数学', term: '2025-2026-1', credit: '3', point: '4', score: '90', nature: '必修', assessment: '考试', attempt: '正常考试', mark: '', ...overrides })
test('weighted GPA includes zero points and excludes missing/nonnumeric values', () => {
  const result = calculateGpa([course(), course({ credit: '1', point: '0' }), course({ point: '' }), course({ point: '优秀' }), course({ credit: '0' })])
  assert.deepEqual(result, { credits: 4, count: 2, skipped: 3, gpa: 3 })
  assert.equal(calculateGpa([]).gpa, null)
})
test('latest attempt wins even when its grade is lower; input order does not matter', () => {
  const older = course(), newer = course({ term: '2025-2026-2', point: '2', score: '70', attempt: '重修' })
  for (const rows of [[older, newer], [newer, older]]) {
    const group = groupGradeAttempts(rows)[0]
    assert.equal(group.records[group.latest].point, '2')
    assert.equal(calculateGpa([group.records[group.latest]]).gpa, 2)
  }
})
test('makeup term takes precedence over original course term', () => {
  const rows = [course({ term: '2024-2025-1', makeupTerm: '2026-2027-1', attempt: '重修', point: '1' }), course({ term: '2025-2026-2' })]
  assert.equal(groupGradeAttempts(rows)[0].latest, 0)
})
test('same-term repeat follows normal attempt; ambiguous repeats need selection', () => {
  assert.equal(groupGradeAttempts([course(), course({ attempt: '重修' })])[0].latest, 1)
  assert.equal(groupGradeAttempts([course({ attempt: '重修' }), course({ attempt: '重修', point: '2' })])[0].latest, null)
  assert.equal(groupGradeAttempts([course(), course({ term: '未知' })])[0].latest, null)
  assert.equal(groupGradeAttempts([course(), course({ makeupTerm: '时间待确认' })])[0].latest, null)
})
test('identity uses course code; missing codes and different codes stay separate', () => {
  assert.equal(groupGradeAttempts([course(), course({ code: 'OTHER' }), course({ code: '' }), course({ code: '' })]).length, 4)
  assert.equal(groupGradeAttempts([course(), course()])[0].latest, 0)
})
