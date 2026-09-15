<script setup lang="ts">
import BlurCard from '~/xupt/components/atomic/BlurCard.vue'
import Link from '~/xupt/components/atomic/Link.vue'
import { interestGroups } from '~/data/interest-groups'
import { getQqGroupAvatar } from '~/xupt/utils/avatar'

const sections = [
  { key: 'game', title: '游戏群' },
  { key: 'other', title: '动漫、音乐与其他兴趣群' },
] as const
</script>

<template>
  <div class="interest-group-directory xupt-coder not-prose">
    <section v-for="section in sections" :key="section.key" class="group-section">
      <h2>{{ section.title }}</h2>
      <div class="group-grid">
        <BlurCard
          v-for="group in interestGroups.filter(item => item.category === section.key)"
          :id="`group-${group.qq}`"
          :key="group.qq"
          class="group-card"
          :avatar="getQqGroupAvatar(group.qq)"
          :name="group.name"
          :tags="group.direction"
          flip
          tabindex="0"
          :aria-label="`${group.name}，${group.direction}，翻面查看并复制群号`"
        >
          <template #back>
            <div class="group-name">{{ group.name }}</div>
            <div class="group-direction">{{ group.direction }}</div>
            <Link icon="ri:qq-fill" copy :text="group.qq" />
          </template>
        </BlurCard>
      </div>
    </section>
  </div>
</template>

<style scoped>
.group-section {
  margin-top: 2rem;
}

.group-section h2 {
  margin-bottom: 1rem;
  font: revert;
}

.group-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1rem;
}

.group-card {
  min-height: 15rem;
  outline: none;
}

.group-card:focus-visible {
  border-radius: 0.5rem;
  box-shadow: 0 0 0 3px var(--vp-c-brand-soft);
}

.group-card:focus-visible :deep(.face),
.group-card:focus-within :deep(.face) {
  transform: rotateY(180deg);
}

.group-card:focus-visible :deep(.back),
.group-card:focus-within :deep(.back) {
  transform: rotateY(0);
}

.group-name {
  font-weight: 700;
  text-wrap: balance;
}

.group-direction {
  color: var(--vp-c-text-2);
  font-size: 0.9rem;
  text-align: center;
}

@media (max-width: 70rem) {
  .group-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 52rem) {
  .group-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 30rem) {
  .group-grid {
    grid-template-columns: 1fr;
  }
}
</style>
