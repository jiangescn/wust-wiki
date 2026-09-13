<script setup lang="ts">
const { sidebarNavigation } = useSubNavigation()
const contentNavVariants = useUIConfig('contentNavigation')
</script>

<template>
  <UContentNavigation
    :collapsible="false"
    :highlight="contentNavVariants.highlight ?? true"
    :highlight-color="contentNavVariants.highlightColor"
    :variant="contentNavVariants.variant ?? 'link'"
    :color="contentNavVariants.color"
    :navigation="sidebarNavigation"
  >
    <template #link-title="{ link, active }">
      <span :class="{ 'draft-title': link.status === 'draft' && !link.children?.length && !active }">{{ link.title }}</span>
    </template>
  </UContentNavigation>
</template>

<style scoped>
.draft-title { color: var(--ui-text-dimmed); }
</style>
