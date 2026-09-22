<script setup lang="ts">
definePageMeta({
  middleware: () => navigateTo('/coder', { redirectCode: 301, replace: true }),
})
</script>

<template>
  <p><NuxtLink to="/coder">进入武科大俱乐部</NuxtLink></p>
</template>
