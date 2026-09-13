// Reference-site relative links must not point at missing WUST pages.
export function referenceLink(value?: string): string | undefined {
  if (!value) return undefined
  if (value.startsWith('/') && !value.startsWith('//')) return `https://wiki.cooo.site${value}`
  return /^https?:\/\//i.test(value) ? value : undefined
}
