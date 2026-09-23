<script setup lang="ts">
definePageMeta({ layout: false })
useSeoMeta({ title: '课表登录模板', robots: 'noindex, nofollow' })
</script>

<template>
  <main class="login-template">
    <NuxtLink to="/study/curriculum">← 课程安排</NuxtLink>
    <h1>课表登录模板</h1>
    <ScheduleLoginTemplates experimental />
  </main>
</template>

<style scoped>
.login-template { max-width: 64rem; margin: 0 auto; padding: 2rem 1.25rem 5rem; }
h1 { font-size: 2rem; font-weight: 700; margin: 1.25rem 0 .5rem; }
@media (max-width: 640px) { h1 { font-size: 1.65rem; } }
</style>
