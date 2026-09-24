<script setup lang="ts">
import { Icon } from '@iconify/vue'
import blogList from '~/data/coder/blog.json'
import BlogCard from '~/xupt/components/unique/BlogCard.vue'

const blogs = ref([...blogList])
const shuffleBlogs = () => blogs.value.sort(() => Math.random() - 0.5)

onNuxtReady(() => {
  if (!location.search.includes('shuffle=false'))
    shuffleBlogs()
})
</script>

<template>
  <h1 class="center-line">
    武科大校友博客索引
    <button type="button" class="shuffle-btn" aria-label="随机排序" title="随机排序" @click="shuffleBlogs">
      <Icon icon="ri:shuffle-fill" aria-hidden="true" />
    </button>
  </h1>

  <div class="center-line vp-doc">
    原来你也写博客
  </div>

  <TransitionGroup tag="section" class="blogs">
    <BlogCard v-for="blog in blogs" :key="blog.link" v-bind="blog" />
  </TransitionGroup>
</template>

<style scoped>
.blogs {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(10em, 1fr));
  gap: 0.5em;
  margin: 2em auto;
}

.center-line {
  margin: 2em 0 2rem;
  font: revert;
  text-align: center;
}

.shuffle-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 2rem;
  min-height: 2rem;
  margin-left: .25rem;
  border-radius: .375rem;
  color: var(--vp-c-text-2);
  vertical-align: middle;
  cursor: pointer;
}
.shuffle-btn:hover { background: var(--vp-c-default-soft); color: var(--vp-c-brand-1); }
.shuffle-btn:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }

.v-move {
  transition: transform 0.3s;
}
</style>
