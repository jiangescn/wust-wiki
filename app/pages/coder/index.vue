<script setup lang="ts">
import CoderDirectory from '~/components/content/CoderDirectory.vue'
definePageMeta({ layout: false })
useSeoMeta({ title: '武科大俱乐部' })
</script>

<template>
  <main class="xupt-coder-page">
    <CoderDirectory kind="labs" />
    <p class="coder-contribute">
      发现遗漏或信息有误？
      <a href="https://github.com/jiangescn/wust-wiki/issues">
        前往 GitHub Issues 补充社团信息
      </a>
    </p>
  </main>
</template>
