<script setup lang="ts">
definePageMeta({ layout: false })
useSeoMeta({ title: '全部文章' })
const { data: pages } = await useAsyncData('all-articles', () => queryCollection('docs').select('path', 'title', 'status', 'updated').order('path', 'ASC').all())
</script>
<template>
  <main class="wiki-articles"><h1>全部文章</h1><ul class="wiki-article-list"><li v-for="page in pages" :key="page.path"><NuxtLink :to="page.path">{{ page.title }}</NuxtLink><span v-if="page.status === 'draft'" class="wiki-draft-label">待补充</span><time v-else-if="page.updated" :datetime="page.updated">{{ page.updated }}</time></li></ul></main>
</template>
