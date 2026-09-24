<script setup lang="ts">
import WustLabList from '~/components/content/WustLabList.vue'
import WustBlogList from '~/components/content/WustBlogList.vue'

defineProps<{ kind: 'labs' | 'blogs'; embedded?: boolean }>()
</script>

<template>
  <section class="xupt-coder">
    <WustLabList v-if="kind === 'labs'" :embedded="embedded" />
    <WustBlogList v-else />
    <p class="reference-note">武科大资料 · 用户提供 · {{ kind === 'labs' ? '2026-09-22' : '2026-09-15' }}</p>
  </section>
</template>
