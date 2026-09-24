import type { LoginView } from '~~/server/utils/login-template-store.mjs'
export type GradeCourse = { term: string; code: string; name: string; score: string; credit: string; point: string; nature: string; assessment: string; attempt: string; mark: string; group?: string; makeupTerm?: string }
export type GradeResult = { provider: 'wust'; courses: GradeCourse[] }
export type AcademicView = { state: string; message?: string; qr?: string; expiresAt?: number; fetchedAt?: number; sessionToken?: string; result?: LoginView['result'] | GradeResult }
