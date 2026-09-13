<script setup lang="ts">
import type { VNode } from 'vue'
// Content 3.15 passes inline text through a slot; blog-v3/Content 3.16 passes code.
const props = defineProps<{ code?: string; language?: string; lang?: string; copy?: boolean }>()
const slots = useSlots()
function text(nodes: VNode[] = []): string {
  return nodes.map(node => typeof node.children === 'string' ? node.children : Array.isArray(node.children) ? text(node.children as VNode[]) : '').join('')
}
</script>
<template><BlogProseCode :code="props.code ?? text(slots.default?.())" :language="language || lang" :copy="copy" /></template>
