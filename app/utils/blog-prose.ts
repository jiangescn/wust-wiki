// Reuse the same Markdown renderer on wiki documents and the upstream showcase.
export const blogProseComponents: Record<string, string> = {
  a: 'BlogProseA', code: 'BlogInlineCodeBridge', pre: 'BlogProsePre', table: 'BlogProseTable',
}
// Paragraph slots are required by Chat/Timeline; headings retain anchor support.
for (const tag of ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']) {
  blogProseComponents[tag] = `Prose${tag.charAt(0).toUpperCase()}${tag.slice(1)}`
}
