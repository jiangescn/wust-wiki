// Plain app config avoids Docus 5.13's editor schema narrowing github to an object.
// Docus supports github: false at runtime; configuration is inferred by Nuxt.
export default {
  title: 'WUST Wiki',
  link: { remindNoFeed: true },
  component: { alert: { defaultStyle: 'card' }, codeblock: { triggerRows: 32, collapsedRows: 16, enableIndentGuide: true, indent: 4, tabSize: 3 } },
  seo: {
    title: 'WUST Wiki',
    titleTemplate: '%s · WUST Wiki',
    description: '武汉科技大学非官方校园生活指南',
  },
  header: { title: 'WUST Wiki' },
  blogComponents: { title: 'WUST Wiki', header: { logo: '/favicon.svg', showTitle: true, subtitle: '武汉科技大学校园指南', emojiTail: ['📚', '🏫', '🌱', '💻', '📝'] } },
  github: false,
  socials: {},
  docus: { locale: 'zh-CN' },
  toc: { title: '本页目录', bottom: { title: '一起完善', links: [
    { label: '贡献指南', to: '/contributing', icon: 'i-lucide-pencil-line' },
    { label: '关于本站', to: '/about', icon: 'i-lucide-info' },
  ] } },
  ui: { colors: { primary: 'blue', neutral: 'zinc' } },
}
