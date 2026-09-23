<script setup lang="ts">
import type { ScheduleResult } from "~/utils/schedule"
const range = (a: number, b: number) => Array.from({length: b-a+1}, (_, i) => a+i)
const courses = [
  { id: 'english-a', name: '大学英语', teacher: '示例教师 A', room: '示例教室 A101', day: 1, slots: [[1, 2]], weeks: range(1, 8), weekLabel: '1–8 周', color: 'blue' },
  { id: 'math-a', name: '高等数学', teacher: '示例教师 B', room: '示例教室 B203', day: 1, slots: [[5, 6]], weeks: range(1, 16), weekLabel: '1–16 周', color: 'purple' },
  { id: 'data-a', name: '数据结构', teacher: '示例教师 C', room: '示例教室 C302', day: 2, slots: [[3, 4]], weeks: range(2, 16), weekLabel: '2–16 周', color: 'teal' },
  { id: 'physics', name: '大学物理', teacher: '示例教师 D', room: '示例教室 A205', day: 3, slots: [[1, 2]], weeks: range(1, 16), weekLabel: '1–16 周', color: 'amber' },
  { id: 'lab', name: '物理实验', teacher: '示例教师 D', room: '示例实验室', day: 3, slots: [[7, 8]], weeks: [2, 4, 6, 8, 10, 12, 14, 16], weekLabel: '2–16 周（双周）', color: 'amber' },
  { id: 'english-b', name: '大学英语', teacher: '示例教师 A', room: '示例教室 A101', day: 4, slots: [[3, 4]], weeks: range(1, 8), weekLabel: '1–8 周', color: 'blue' },
  { id: 'writing', name: '学术写作', teacher: '示例教师 E', room: '示例教室 A101', day: 4, slots: [[3, 4]], weeks: range(9, 16), weekLabel: '9–16 周', color: 'rose' },
  { id: 'sport', name: '体育', teacher: '示例教师 F', room: '示例运动场', day: 4, slots: [[7, 8]], weeks: range(1, 16), weekLabel: '1–16 周', color: 'lime' },
  { id: 'data-b', name: '数据结构', teacher: '示例教师 C', room: '示例教室 C302', day: 5, slots: [[3, 4]], weeks: range(2, 16), weekLabel: '2–16 周', color: 'teal' },
  { id: 'practice', name: '程序设计实践', teacher: '示例教师 G', room: '示例机房', day: 5, slots: [[7], [9]], weeks: [3, 4, 5, 7], weekLabel: '3–5、7 周', color: 'purple' },
  { id: 'seminar', name: '创新研讨', teacher: '示例教师 H', room: '示例研讨室', day: 6, slots: [[5, 6]], weeks: [1, 3, 5, 7, 9, 11, 13, 15], weekLabel: '1–15 周（单周）', color: 'rose' },
  { id: 'online', name: '艺术鉴赏', teacher: '未提供', room: '在线课程（示例）', day: 7, slots: [[12]], weeks: range(1, 16), weekLabel: '1–16 周', color: 'blue' },
]

const result: ScheduleResult = {provider: "wust", schoolYear: "示例", semester: 1, lessons: courses.map(c => ({name:c.name,teacher:c.teacher,location:c.room,day:c.day,sections:c.slots.map(s=>s.length===1?String(s[0]):s[0]+"-"+s.at(-1)).join(","),weeks:c.weeks.join(",")})), notes:["实践课程（示例）：未提供具体星期与节次。"]}
</script>
<template><ScheduleBoard :result="result" demo /></template>
