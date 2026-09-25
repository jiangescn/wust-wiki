<script setup lang="ts">
import { wikiNavigation } from '~/data/wiki'
const { open: searchOpen } = useContentSearch()
</script>

<template>
  <UHeader :ui="{ container: 'max-w-[1440px]', left: 'gap-6', center: 'hidden' }">
    <template #left>
      <NuxtLink to="/" aria-label="WUST Wiki 首页"><AppHeaderLogo /></NuxtLink>
      <UContentSearchButton label="搜索" :collapsed="false" class="hidden md:flex">
        <template #trailing>
          <span class="search-keys" aria-label="Control K" @click.capture="searchOpen = true">
            <BlogKey code="Control" />
            <BlogKey code="k" text="K" ctrl />
          </span>
        </template>
      </UContentSearchButton>
    </template>
    <template #right>
      <UNavigationMenu :items="wikiNavigation" class="hidden lg:flex" :ui="{ link: 'text-sm' }" />
      <UContentSearchButton class="md:hidden" />
      <UColorModeButton />
      <UButton
        icon="i-simple-icons-github"
        to="https://github.com/jiangescn/wust-wiki"
        target="_blank"
        rel="noopener noreferrer"
        color="neutral"
        variant="ghost"
        aria-label="WUST Wiki GitHub 仓库"
        title="GitHub 仓库"
      />
    </template>
    <template #body>
      <UNavigationMenu :items="wikiNavigation" orientation="vertical" />
    </template>
  </UHeader>
</template>
