<script setup lang="ts">
import LabList from '~/xupt/components/unique/LabList.vue'
import BlogList from '~/xupt/components/unique/BlogList.vue'
import CoderGuild from '~/xupt/components/unique/CoderGuild.vue'

defineProps<{ kind: 'labs' | 'blogs' }>()
</script>

<template>
  <section class="xupt-coder">
    <LabList v-if="kind === 'labs'"><CoderGuild /></LabList>
    <BlogList v-else />
    <p class="reference-note">西邮参考名单 · <a :href="kind === 'labs' ? 'https://wiki.cooo.site/coder/' : 'https://wiki.cooo.site/coder/blog'" target="_blank" rel="noopener noreferrer">西邮 Wiki</a></p>
  </section>
</template>
