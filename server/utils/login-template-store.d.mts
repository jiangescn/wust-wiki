export type LoginProvider = 'chaoxing' | 'wust' | 'helper'
export type LoginView = {
  provider?: LoginProvider
  state: string
  message: string
  qr?: string
  expiresAt?: number
  result?: {
    provider: LoginProvider
    curriculumUuid?: string
    schoolYear?: string
    semester?: number
    currentWeek?: number
    maxWeek?: number
    notes?: string[]
    lessons: { name: string; teacher: string; location: string; day?: number; start?: number; length?: number; end?: number; weeks?: string; sections?: string; group?: string }[]
  }
}
export function isLocalLoginRequest(input: { enabled: boolean; host: string; origin: string; address: string; devTransport?: boolean; lanHosts?: string[] }): boolean
export function createLoginStore(): {
  providers: { id: LoginProvider; title: string; scanner: string; description: string; boundary: string; officialUrl: string }[]
  start(owner: string, provider: LoginProvider): Promise<LoginView>
  poll(owner: string): Promise<LoginView>
  clear(owner: string): LoginView
  snapshot(owner: string): LoginView
  dispose(): void
}
