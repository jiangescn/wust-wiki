<script setup lang="ts">
import CoderDirectory from '~/components/content/CoderDirectory.vue'
definePageMeta({ layout: false })
useSeoMeta({ title: '武科大校友博客' })
</script>

<template>
  <main class="xupt-coder-page">
    <CoderDirectory kind="blogs" />
    <p class="coder-contribute">
      想推荐更多武科大校友博客？
      <a href="https://github.com/jiangescn/wust-wiki/issues">
        前往 GitHub Issues 补充博客信息
      </a>
    </p>
  </main>
</template>
