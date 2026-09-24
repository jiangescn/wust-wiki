export function createAcademicStore(): {
  handle(input: { body: unknown; authorization?: string; origin: string }): Promise<{ status: number; data: Record<string, unknown> }>
  dispose(): void
}
export const ACADEMIC_TTL: number
