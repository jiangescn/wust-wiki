import { fileURLToPath, pathToFileURL } from 'node:url'
import { readdirSync, readFileSync } from 'node:fs'
import { addComponent } from 'nuxt/kit'

const sourceIcons = [...new Set([
  ...readdirSync(fileURLToPath(new URL('./app/clarity/components', import.meta.url))).flatMap(file => [...readFileSync(fileURLToPath(new URL(`./app/clarity/components/${file}`, import.meta.url)), 'utf8').matchAll(/(?:tabler|ri|catppuccin|simple-icons|line-md):[a-z0-9-]+/g)].map(match => match[0])),
  ...[...readFileSync(fileURLToPath(new URL('./app/utils/icon.ts', import.meta.url)), 'utf8').matchAll(/(?:tabler|ri|catppuccin|simple-icons|line-md):[a-z0-9-]+/g)].map(match => match[0]),
  'catppuccin:file', 'catppuccin:yaml', 'catppuccin:changelog', 'catppuccin:markdown', 'catppuccin:typescript', 'lucide:pencil-line',
  'lucide:utensils', 'lucide:star', 'lucide:search', 'lucide:refresh-cw', 'lucide:map-pin', 'lucide:message-square', 'lucide:arrow-right', 'lucide:image',
])]

export default defineNuxtConfig({
  extends: ['docus'],
  runtimeConfig: {
    public: {
      foodApiBase: process.env.NUXT_PUBLIC_FOOD_API_BASE || '/api/food',
      // The bridge owns GeeTest and the API call; this site only renders approved results.
      dormitoryEmbedUrl: process.env.NUXT_PUBLIC_DORMITORY_EMBED_URL || 'https://dorm.wustacm.com/embed',
    },
  },
  // Nuxt deliberately excludes vendor from automatic scans; register originals explicitly.
  modules: ['@pinia/nuxt', '@vueuse/nuxt', '@nuxt/image', '@bikariya/image-viewer', '@bikariya/modals', '@bikariya/shiki', () => {
    for (const file of readdirSync(fileURLToPath(new URL('./app/clarity/components', import.meta.url)))) {
      const name = file.replace(/\.vue$/, '')
      addComponent({ name: `Blog${name}`, filePath: fileURLToPath(new URL(`./app/clarity/components/${name}.vue`, import.meta.url)).replaceAll('\\', '/'), global: true })
    }
    for (const [name, path] of Object.entries({ UtilImg: 'util/Img.vue', UtilLink: 'util/Link.vue', UtilHydrateSafe: 'util/HydrateSafe.vue', ZButton: 'partial/Button.vue', PopoverLightbox: 'popover/Lightbox.vue', FeedCard: 'components/FeedCard.vue', BlogHeader: 'blog/BlogHeader.global.vue' })) {
      addComponent({ name, filePath: fileURLToPath(new URL(`./app/clarity/${path}`, import.meta.url)).replaceAll('\\', '/'), global: true })
    }
  }],
  css: ['~/assets/blog-components.scss', 'katex/dist/katex.min.css', 'tippy.js/dist/tippy.css', '~/assets/xupt-variables.css', '~/assets/xupt-coder.css'],
  vite: { css: { preprocessorOptions: { scss: { additionalData: '@use "~~/vendor/blog-v3/styles/_variable.scss" as *;' } } } },
  image: { provider: 'none' },
  icon: { clientBundle: { icons: sourceIcons } },
  alias: {
    'https://esm.sh/shiki/langs': 'shiki/langs',
    'https://esm.sh/shiki/engine-oniguruma.mjs': 'shiki/engine-oniguruma',
    'https://esm.sh/shiki/wasm': 'shiki/wasm',
  },
  content: { build: { markdown: {
    remarkPlugins: {
      'remark-math': {},
      [pathToFileURL(fileURLToPath(new URL('./vendor/blog-v3/remark-plugins/remark-code-component.ts', import.meta.url))).href]: { options: { mermaid: { component: 'blog-mermaid', prop: 'code' }, 'music-abc': { component: 'blog-music-score', prop: 'abc' } } },
    },
    rehypePlugins: {
      'rehype-katex': {},
      [pathToFileURL(fileURLToPath(new URL('./vendor/blog-v3/remark-plugins/rehype-meta-slots.ts', import.meta.url))).href]: {},
    },
  } } },
  compatibilityDate: '2026-09-12',
  devtools: { enabled: false },
  docus: { assistant: { enabled: false } },
  llms: { domain: process.env.NUXT_SITE_URL || 'http://localhost:3000' },
  site: {
    name: 'WUST Wiki',
  },
  app: {
    head: {
      htmlAttrs: { lang: 'zh-CN' },
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    },
  },
  fonts: { providers: { google: false, googleicons: false, bunny: false, fontshare: false, npm: false } },
  ogImage: { enabled: false },
  mcp: { enabled: false },
  nitro: {
    prerender: { failOnError: true, autoSubfolderIndex: true, routes: ['/previews/example'] },
  },
})

