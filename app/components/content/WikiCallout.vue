<script setup lang="ts">
// Adapted from Zhilu's blog-v3 Alert.vue (MIT). Configuration and colors decoupled.
const props = withDefaults(defineProps<{ type?: 'tip' | 'info' | 'warning'; title?: string }>(), { type: 'tip' })
const types = {
  tip: { title: '小提示', icon: 'i-lucide-lightbulb' },
  info: { title: '说明', icon: 'i-lucide-info' },
  warning: { title: '请留意', icon: 'i-lucide-triangle-alert' },
}
const config = computed(() => types[props.type] || types.info)
</script>

<template>
  <aside class="wiki-callout" :class="`wiki-callout-${type}`" :aria-label="title || config.title">
    <div class="wiki-callout-title"><UIcon :name="config.icon" aria-hidden="true" />{{ title || config.title }}</div>
    <div class="wiki-callout-body"><slot /></div>
  </aside>
</template>
