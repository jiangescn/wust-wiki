<script setup lang="ts">
import BlogList from '~/xupt/components/unique/BlogList.vue'
import WustLabList from '~/components/content/WustLabList.vue'

defineProps<{ kind: 'labs' | 'blogs' }>()
</script>

<template>
  <section class="xupt-coder">
    <WustLabList v-if="kind === 'labs'" />
    <BlogList v-else />
    <p v-if="kind === 'labs'" class="reference-note">武科大首批资料 · 用户提供 · 2026-09-15</p>
    <p v-else class="reference-note">西邮参考名单 · <a href="https://wiki.cooo.site/coder/blog" target="_blank" rel="noopener noreferrer">西邮 Wiki</a></p>
  </section>
</template>
