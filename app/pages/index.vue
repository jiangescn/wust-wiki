<script setup lang="ts">
import { homeEntries } from '~/data/wiki'
definePageMeta({ layout: false })
useSeoMeta({ title: '首页', description: '武汉科技大学非官方校园生活指南' })
const { data: updates } = await useAsyncData('recent-updates', () => queryCollection('docs')
  .where('status', '=', 'published').where('updated', 'IS NOT NULL')
  .where('path', '<>', '/changelog')
  .order('updated', 'DESC').order('path', 'ASC').select('path', 'title', 'updated').limit(5).all())
</script>

<template>
  <main class="wiki-home">
    <section class="wiki-hero">
      <div><h1>WUST Wiki</h1><p>武汉科技大学非官方校园生活指南</p>
        <div class="wiki-hero-actions">
          <UButton to="/campus" size="xl" class="rounded-full">开始阅读</UButton>
          <UButton to="/navigation" size="xl" color="neutral" variant="soft" class="rounded-full">武科大导航</UButton>
        </div>
      </div>
      <img src="/favicon.svg" alt="" class="wiki-hero-logo" width="156" height="156">
    </section>
    <section class="wiki-entry-grid" aria-label="校园指南入口">
      <NuxtLink v-for="item in homeEntries" :key="item.to" :to="item.to" class="wiki-entry">
        <span class="wiki-entry-emoji" aria-hidden="true">{{ item.icon }}</span>
        <h2>{{ item.title }}</h2><p>{{ item.description }}</p>
      </NuxtLink>
    </section>
    <section class="wiki-updates" aria-labelledby="updates-title">
      <div class="wiki-section-heading"><h2 id="updates-title">最近更新</h2><NuxtLink to="/changelog">完整更新日志 <span aria-hidden="true">→</span></NuxtLink></div>
      <ul v-if="updates?.length" class="wiki-update-list"><li v-for="page in updates" :key="page.path"><NuxtLink :to="page.path">{{ page.title }}</NuxtLink><time :datetime="page.updated">{{ page.updated }}</time></li></ul>
      <p v-else class="wiki-empty">暂无更新</p>
    </section>
  </main>
</template>
