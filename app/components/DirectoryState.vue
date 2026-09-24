<script setup lang="ts">
defineProps<{ title: string; description?: string; actionLabel?: string }>()
defineEmits<{ action: [] }>()
</script>

<template>
  <UEmpty :title="title" :description="description" size="sm" variant="soft" class="directory-state not-prose">
    <template v-if="actionLabel" #actions>
      <UButton type="button" color="neutral" variant="outline" size="sm" @click="$emit('action')">{{ actionLabel }}</UButton>
    </template>
  </UEmpty>
</template>

<style scoped>
.directory-state { margin-block: 1rem; border-radius: 12px; }
.directory-state :deep([data-slot=title]) { margin: 0; font-size: .875rem; line-height: 1.5; }
</style>
