<script setup lang="ts">
import LinkList from '~/xupt/components/unique/LinkList.vue'
import { campusApps } from '~/data/campus-apps'
const props = defineProps<{ group: keyof typeof campusApps }>()
const links = computed(() => campusApps[props.group])
</script>

<template>
  <div class="xupt-coder not-prose"><LinkList :links="links" desc-lines="unset" width="min(100%, 13rem)" /></div>
</template>
