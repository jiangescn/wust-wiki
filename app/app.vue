<script setup lang="ts">
import type { ContentNavigationItem } from '@nuxt/content'
import { zh_cn } from '@nuxt/ui/locale'
const locale = {
  ...zh_cn,
  messages: {
    ...zh_cn.messages,
    contentSearch: { ...zh_cn.messages.contentSearch, title: '搜索文档', description: '搜索校园指南' },
    header: { ...zh_cn.messages.header, title: '导航菜单', description: '选择栏目' },
  },
}
useHead({ htmlAttrs: { lang: 'zh-CN' }, link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }] })
useSeoMeta({ titleTemplate: '%s · WUST Wiki', description: '武汉科技大学非官方校园生活指南' })
// Section index documents (e.g. /campus) must not stay active on child pages.
function exactDocumentLinks(items: ContentNavigationItem[]): ContentNavigationItem[] {
  return items.map(item => ({
    ...item,
    exact: true,
    ...(item.children ? { children: exactDocumentLinks(item.children) } : {}),
  }))
}
const { data: navigation } = await useAsyncData('wiki-navigation-with-status', () => queryCollectionNavigation('docs', ['status']), {
  transform: exactDocumentLinks,
})
provide('navigation', navigation)
</script>

<template>
  <UApp :locale="locale">
    <NuxtLoadingIndicator color="var(--ui-primary)" />
    <AppHeader />
    <NuxtLayout><NuxtPage :transition="{ name: 'wiki-page', mode: 'out-in' }" /></NuxtLayout>
    <AppFooter />
    <BikariyaModals />
    <ClientOnly><AppSearch :navigation="navigation || undefined" /></ClientOnly>
  </UApp>
</template>
