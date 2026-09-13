<script setup lang="ts">
// Adapted from Zhilu's blog-v3 LinkCard.vue (MIT). See THIRD_PARTY_NOTICES.md.
const props = defineProps<{ link: string; title: string; description?: string; icon?: string }>()
const external = computed(() => /^https?:\/\//i.test(props.link))
</script>

<template>
  <NuxtLink :to="link" :target="external ? '_blank' : undefined" :rel="external ? 'noopener noreferrer' : undefined" class="wiki-link-card">
    <UIcon v-if="icon" :name="icon" class="wiki-link-card-icon" aria-hidden="true" />
    <span class="wiki-link-card-info">
      <span class="wiki-link-card-title">{{ title }}</span>
      <span v-if="description" class="wiki-link-card-description">{{ description }}</span>
    </span>
    <UIcon :name="external ? 'i-lucide-arrow-up-right' : 'i-lucide-arrow-right'" class="wiki-link-card-arrow" aria-hidden="true" />
  </NuxtLink>
</template>
