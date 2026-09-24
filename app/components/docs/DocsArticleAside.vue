<script setup lang="ts">
import { blogProseComponents } from '~/utils/blog-prose'

defineProps<{
  slots: Record<string, {
    type: 'minimark'
    value: unknown[]
    props?: { title?: string }
  }>
}>()
</script>

<template>
  <aside class="blog-components wiki-article-aside" aria-label="文章补充信息">
    <section v-for="(slot, name) in slots" :key="name" class="article">
      <h2 v-if="slot.props?.title" class="aside-title">{{ slot.props.title }}</h2>
      <ContentRenderer :value="slot" :components="blogProseComponents" :prose="false" />
    </section>
    <section v-if="!slots['aside-contribute']" class="article wiki-feedback">
      <BlogLinkCard
        title="补充与纠正"
        description="信息有误或缺漏？欢迎补充。"
        link="https://github.com/jiangescn/wust-wiki/issues"
      />
    </section>
  </aside>
</template>

<style scoped>
.wiki-article-aside { min-width: 0; }
.wiki-article-aside section + section { margin-top: 1rem; }
.aside-title { margin: 0 0 .75rem; font-size: 1rem; font-weight: 600; }
.wiki-article-aside :deep(.link-card) { border-radius: 12px; }
.wiki-feedback { margin: 0; }
.wiki-feedback :deep(.link-card) { width: 100%; max-width: 100%; margin: 0; }
.wiki-feedback :deep(.link-card-description) { white-space: normal; color: var(--c-text-2); opacity: 1; }
</style>
