<script setup lang="ts">
import type { FoodComment } from '~/types/food'
import { foodMediaUrl } from '~/utils/food-api'
import FoodImage from './FoodImage.vue'
import FoodRating from './FoodRating.vue'
defineProps<{ items: FoodComment[]; apiBase: string; showDish?: boolean }>()
defineEmits<{ dish: [id: string]; preview: [url: string] }>()
const date = (value: number) => new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit' }).format(value)
const medium = (url: string, apiBase: string) => foodMediaUrl(url.replace(/(\/media\/[a-f0-9-]{36})(?:\/(?:thumbnail|medium))?$/i, '$1/medium'), apiBase)
</script>

<template>
  <div class="food-reviews">
    <article v-for="item in items" :key="item.id" class="food-review" data-food-review>
      <div class="review-heading">
        <UAvatar :src="foodMediaUrl(item.authorAvatarFileId, apiBase) || undefined" :alt="item.authorLabel" size="sm" />
        <div class="review-author"><span>{{ item.authorLabel }}</span><time :datetime="new Date(item.createdAt).toISOString()">{{ date(item.createdAt) }}</time></div>
        <span class="review-rating"><span>当时评分</span><FoodRating :rating="item.ratingSnapshot" /></span>
      </div>
      <p v-if="item.content" class="review-text">{{ item.content }}</p>
      <div v-if="item.images.length" class="review-images" :class="`review-images-${item.images.length}`">
        <button v-for="(url, index) in item.images" :key="url" type="button" :aria-label="`查看评价图片 ${index + 1}`" @click="$emit('preview', foodMediaUrl(item.imageDisplayUrls[index] || url, apiBase))">
          <FoodImage :src="medium(url, apiBase)" :alt="`评价图片 ${index + 1}`" />
        </button>
      </div>
      <div v-if="showDish && item.dishName" class="review-dish">
        <UButton color="primary" variant="link" :padded="false" trailing-icon="i-lucide-arrow-right" @click="$emit('dish', item.dishId)">{{ item.dishName }}</UButton>
        <span>{{ item.locationText }}</span>
      </div>
    </article>
  </div>
</template>

<style scoped>
.food-review { padding: 1.5rem 0; border-bottom: 1px solid var(--ui-border); }
.food-review:first-child { padding-top: .25rem; }
.review-heading { display: flex; align-items: center; gap: .65rem; }
.review-author { flex: 1; min-width: 0; font-size: .85rem; font-weight: 550; }
.review-author span { display: block; overflow-wrap: anywhere; }
.review-author time { display: block; color: var(--ui-text-muted); font-size: .75rem; font-weight: 400; }
.review-rating { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; }
.review-rating > span { font-size: .65rem; color: var(--ui-text-muted); }
.review-text { white-space: pre-wrap; overflow-wrap: anywhere; font-size: .9rem; line-height: 1.8; margin: .85rem 0 !important; }
.review-images { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .5rem; margin-top: .75rem; }
.review-images-1 { grid-template-columns: 1fr; }
.review-images-3 > :first-child { grid-column: 1 / -1; }
.review-images button { display: block; width: 100%; min-width: 0; cursor: zoom-in; border-radius: .5rem; }
.review-images button:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 3px; }
.review-dish { display: flex; flex-direction: column; align-items: flex-start; gap: .2rem; margin-top: .85rem; padding: .7rem .85rem; border-radius: .5rem; background: var(--ui-bg-muted); }
.review-dish span { color: var(--ui-text-muted); font-size: .75rem; }
@media (max-width: 420px) { .review-heading { gap: .5rem; } .review-author { font-size: .8rem; } }
</style>
