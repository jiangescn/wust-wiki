<script setup lang="ts">
import type { Canteen, Dish, FoodComment, FoodStall } from '~/types/food'
import { createFoodApi, foodMediaUrl, foodPrice } from '~/utils/food-api'
import FoodImage from '~/components/food/FoodImage.vue'
import FoodReviews from '~/components/food/FoodReviews.vue'
import FoodRating from '~/components/food/FoodRating.vue'

const apiBase = String(useRuntimeConfig().public.foodApiBase)
const api = createFoodApi(apiBase)
const canteens = ref<Canteen[]>([])
const canteenId = ref('')
const tab = ref('menu')
const tabs = [{ label: '菜品目录', value: 'menu' }, { label: '口碑排行', value: 'ranking' }, { label: '最新评价', value: 'reviews' }]
const catalog = ref<Dish[]>([])
const stalls = ref<FoodStall[]>([])
const activeStall = ref<FoodStall>()
const shopHeader = ref<HTMLElement>()
const ranked = ref<Dish[]>([])
const reviews = ref<FoodComment[]>([])
const query = ref('')
const floorId = ref('all')
const shopSort = ref('menu')
const categoryLabels: Record<string, string> = { rice: '饭类', noodles: '粉面', snack: '小吃', dessert: '甜点', drink: '饮品', other: '其他' }
const sort = ref('rating')
const visibleCount = ref(12)
const nextCursor = ref<string>()
const loading = ref(true)
const error = ref('')
const initialError = ref('')
let listRequest = 0
let initRequest = 0

const currentCanteen = computed(() => canteens.value.find(item => item.id === canteenId.value))
const floorOptions = computed(() => [{ label: '全部楼层', value: 'all' }, ...Array.from(new Map(stalls.value.map(stall => [stall.floorId, { label: stall.floorName, value: stall.floorId }])).values())])
const filteredStalls = computed(() => {
  const keyword = query.value.trim().toLocaleLowerCase()
  return stalls.value.filter(stall => (floorId.value === 'all' || stall.floorId === floorId.value)
    && (!keyword || [stall.name, categoryLabels[stall.primaryCategory], stall.description].join(' ').toLocaleLowerCase().includes(keyword)))
    .sort((a, b) => {
      if (shopSort.value === 'rating') return (b.rating ?? -1) - (a.rating ?? -1) || b.ratingCount - a.ratingCount || a.name.localeCompare(b.name, 'zh-CN')
      if (shopSort.value === 'name') return a.name.localeCompare(b.name, 'zh-CN')
      return 0
    })
})
const shownStalls = computed(() => filteredStalls.value.slice(0, visibleCount.value))
const filtered = computed(() => {
  const keyword = query.value.trim().toLocaleLowerCase()
  return catalog.value.filter(dish => !keyword || [dish.name, dish.category, ...dish.tags].join(' ').toLocaleLowerCase().includes(keyword))
    .sort((a, b) => {
      if (sort.value === 'price') return a.price - b.price || a.name.localeCompare(b.name, 'zh-CN')
      if (sort.value === 'rating') return (b.rating ?? -1) - (a.rating ?? -1) || b.ratingCount - a.ratingCount || a.name.localeCompare(b.name, 'zh-CN')
      return a.stallName.localeCompare(b.stallName, 'zh-CN') || a.sortOrder - b.sortOrder || a.name.localeCompare(b.name, 'zh-CN')
    })
})
const shownDishes = computed(() => tab.value === 'menu' ? filtered.value.slice(0, visibleCount.value) : ranked.value)
const menuCount = computed(() => activeStall.value ? filtered.value.length : filteredStalls.value.length)
const hasMore = computed(() => tab.value === 'menu' ? visibleCount.value < menuCount.value : Boolean(nextCursor.value))
const empty = computed(() => tab.value === 'reviews' ? !reviews.value.length : tab.value === 'menu' && !activeStall.value ? !shownStalls.value.length : !shownDishes.value.length)
const media = (value?: string) => foodMediaUrl(value, apiBase)
const message = (reason: unknown) => reason instanceof Error ? reason.message : '加载失败，请稍后重试'

async function initialize() {
  const request = ++initRequest
  initialError.value = ''; loading.value = true
  try {
    const result = await api.canteens()
    if (request !== initRequest) return
    // Keep the API's order for other canteens; South is the Wiki's default entry.
    canteens.value = [...result].sort((a, b) => Number(b.id === 'canteen-nanyuan') - Number(a.id === 'canteen-nanyuan'))
    if (!result.length) { loading.value = false; return }
    const firstId = canteens.value[0]!.id
    if (canteenId.value === firstId) await loadList()
    else canteenId.value = firstId
  } catch (reason) {
    if (request !== initRequest) return
    initialError.value = message(reason); loading.value = false
  }
}

async function loadList(append = false) {
  if (!canteenId.value) return
  const request = ++listRequest
  const scope = canteenId.value
  const mode = tab.value
  const shop = activeStall.value
  const cursor = append ? nextCursor.value : undefined
  loading.value = true; error.value = ''
  if (!append) { catalog.value = []; if (!shop) stalls.value = []; ranked.value = []; reviews.value = []; nextCursor.value = undefined; visibleCount.value = 12 }
  try {
    if (mode === 'menu') {
      // Fetch only the storefront feed until a visitor opens a specific menu.
      if (shop) {
        const result = await api.stallDishes(shop.id)
        if (request === listRequest) catalog.value = result
      } else {
        const result = await api.stalls(scope)
        if (request === listRequest) stalls.value = result
      }
    } else if (mode === 'ranking') {
      const result = await api.reputation(scope, cursor)
      if (request === listRequest) { ranked.value = append ? [...ranked.value, ...result.items] : result.items; nextCursor.value = result.nextCursor }
    } else {
      const result = await api.reviews(scope, cursor)
      if (request === listRequest) { reviews.value = append ? [...reviews.value, ...result.items] : result.items; nextCursor.value = result.nextCursor }
    }
  } catch (reason) {
    if (request === listRequest) error.value = message(reason)
  } finally {
    if (request === listRequest) loading.value = false
  }
}
function loadMore() {
  if (tab.value === 'menu') visibleCount.value += 12
  else void loadList(true)
}
function clearFilters() { query.value = ''; floorId.value = 'all' }
async function showStall(stall: FoodStall) {
  activeStall.value = stall; query.value = ''; void loadList()
  await nextTick()
  shopHeader.value?.scrollIntoView({ block: 'start', behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' })
}
function backToStalls() { activeStall.value = undefined; query.value = ''; void loadList() }
watch([canteenId, tab], () => { activeStall.value = undefined; clearFilters(); void loadList() })
watch([query, floorId, sort, shopSort], () => { visibleCount.value = 12 })
onMounted(initialize)

const detailOpen = ref(false)
const selectedId = ref('')
const detail = ref<Dish>()
const detailLoading = ref(false)
const detailError = ref('')
const comments = ref<FoodComment[]>([])
const commentsCursor = ref<string>()
const commentsLoading = ref(false)
const commentsError = ref('')
const previewUrl = ref('')
const previewOpen = ref(false)
let detailRequest = 0
let commentsRequest = 0

async function showDish(id: string) {
  selectedId.value = id; detailOpen.value = true
  detail.value = undefined; detailError.value = ''; detailLoading.value = true
  comments.value = []; commentsCursor.value = undefined
  const request = ++detailRequest
  void loadComments(false)
  try {
    const result = await api.dish(id)
    if (request === detailRequest) detail.value = result
  } catch (reason) {
    if (request === detailRequest) detailError.value = message(reason)
  } finally { if (request === detailRequest) detailLoading.value = false }
}
async function loadComments(append = false) {
  const request = ++commentsRequest
  commentsLoading.value = true; commentsError.value = ''
  try {
    const result = await api.comments(selectedId.value, append ? commentsCursor.value : undefined)
    if (request !== commentsRequest) return
    comments.value = append ? [...comments.value, ...result.items] : result.items
    commentsCursor.value = result.nextCursor
  } catch (reason) {
    if (request === commentsRequest) commentsError.value = message(reason)
  } finally { if (request === commentsRequest) commentsLoading.value = false }
}
function preview(url: string) { if (url) { previewUrl.value = url; previewOpen.value = true } }
watch(detailOpen, open => { if (!open) { detailRequest++; commentsRequest++ } })
onBeforeUnmount(() => { listRequest++; initRequest++; detailRequest++; commentsRequest++ })
</script>

<template>
  <section class="food-directory not-prose" aria-label="食堂菜品与评价">
    <div class="food-source"><UBadge color="neutral" variant="subtle">吃在武科</UBadge><span>菜品与评价来自同一份餐饮目录</span></div>
    <div v-if="initialError" class="food-state" role="alert">
      <p>食堂信息暂时无法加载</p><span>{{ initialError }}</span><UButton variant="soft" @click="initialize">重新加载</UButton>
    </div>
    <template v-else>
      <div class="food-scopes" aria-label="选择食堂">
        <UButton v-for="canteen in canteens" :key="canteen.id" :variant="canteenId === canteen.id ? 'soft' : 'ghost'" :color="canteenId === canteen.id ? 'primary' : 'neutral'" :aria-pressed="canteenId === canteen.id" @click="canteenId = canteen.id">{{ canteen.name }}</UButton>
      </div>
      <div v-if="currentCanteen" class="food-scope-note"><UIcon name="i-lucide-map-pin" aria-hidden="true" />{{ currentCanteen.location }}<span>·</span>价格及营业情况以现场为准</div>
      <UTabs v-model="tab" :items="tabs" :content="false" variant="link" class="food-tabs" />
      <div :class="{ 'food-shop-view': tab === 'menu' && activeStall }">
      <div v-if="tab === 'menu' && activeStall" ref="shopHeader" class="food-shop-header">
        <UButton color="neutral" variant="ghost" size="sm" @click="backToStalls">← 返回店铺目录</UButton>
        <h3>{{ activeStall.name }}</h3>
        <p>{{ activeStall.address || `${currentCanteen?.shortName} · ${activeStall.floorName}` }}<span v-if="activeStall.openTime"> · {{ activeStall.openTime }}</span></p>
      </div>
      <div v-if="tab === 'menu' && canteens.length" class="food-filters" :class="{ 'food-filters-menu': activeStall }">
        <UInput v-model="query" icon="i-lucide-search" :placeholder="activeStall ? '搜索这家店的菜品' : '搜索当前食堂的店铺、主营类别'" :aria-label="activeStall ? '搜索店内菜品' : '搜索店铺'" class="food-search" />
        <div v-if="!activeStall" class="food-window-select"><USelect v-model="floorId" :items="floorOptions" aria-label="筛选楼层" class="w-full" /></div>
        <div v-if="!activeStall" class="food-sort-select"><USelect v-model="shopSort" :items="[{ label: '默认顺序', value: 'menu' }, { label: '评分优先', value: 'rating' }, { label: '按店名排列', value: 'name' }]" aria-label="店铺排序" class="w-full" /></div>
        <div v-else class="food-sort-select"><USelect v-model="sort" :items="[{ label: '评分优先', value: 'rating' }, { label: '菜单顺序', value: 'menu' }, { label: '单价从低到高', value: 'price' }]" aria-label="菜品排序" class="w-full" /></div>
      </div>
      <div class="food-list-heading">
        <span v-if="tab === 'menu'">{{ loading ? '正在读取目录…' : activeStall ? `找到 ${menuCount} 道菜品` : `找到 ${menuCount} 家店铺 · 点击查看菜单` }}<span v-if="activeStall && sort === 'price'"> · 留意计价单位</span></span>
        <span v-else-if="tab === 'ranking'">综合评分与评分人数排序</span>
        <span v-else>按发布时间排列 · 仅展示已审核评价</span>
        <UButton v-if="canteens.length" color="neutral" variant="ghost" size="xs" icon="i-lucide-refresh-cw" :loading="loading" @click="loadList()">刷新</UButton>
      </div>
      <div v-if="loading && empty" class="food-skeleton-grid" aria-label="正在加载餐饮数据" aria-busy="true"><USkeleton v-for="n in 4" :key="n" class="food-skeleton" /></div>
      <div v-if="error" class="food-state" role="alert"><p>暂时无法读取{{ tab === 'reviews' ? '评价' : tab === 'menu' && !activeStall ? '店铺' : '菜品' }}</p><span>{{ error }}</span><UButton variant="soft" @click="loadList(Boolean(nextCursor))">重试</UButton></div>
      <div v-else-if="!loading && empty" class="food-state" role="status">
        <UIcon :name="tab === 'reviews' ? 'i-lucide-message-square' : 'i-lucide-utensils'" class="food-state-icon" aria-hidden="true" />
        <p>{{ tab === 'reviews' ? '这里还没有公开评价' : tab === 'ranking' ? '这里还没有已评分的菜品' : activeStall ? '没有找到符合条件的菜品' : '没有找到符合条件的店铺' }}</p>
        <span>{{ tab === 'menu' ? '试试其他关键词或筛选条件。' : '可以切换食堂，或先浏览菜品目录。' }}</span>
        <UButton v-if="tab === 'menu' && (query || floorId !== 'all')" variant="soft" @click="clearFilters">清除筛选</UButton>
      </div>
      <FoodReviews v-if="tab === 'reviews'" :items="reviews" :api-base="apiBase" show-dish class="food-social-feed" @dish="showDish" @preview="preview" />
      <ol v-else-if="tab === 'ranking'" class="food-ranking" aria-label="菜品口碑排名">
        <li v-for="(dish, index) in ranked" :key="dish.id">
          <button type="button" class="food-rank-row" :class="{ 'food-rank-top': index < 3 }" :aria-label="`第${index + 1}名，查看${dish.name}的菜品详情和评价`" @click="showDish(dish.id)">
            <span class="food-rank-number" :data-rank="index + 1">{{ String(index + 1).padStart(2, '0') }}</span>
            <FoodImage :src="media(dish.cover?.thumbnailUrl)" :alt="dish.name" class="food-rank-image" />
            <span class="food-rank-copy"><span class="food-rank-name">{{ dish.name }}</span><span class="food-rank-location">{{ dish.floorName }} · {{ dish.stallName }}</span><span class="food-price">{{ foodPrice(dish) }}</span></span>
            <span class="food-rank-rating"><FoodRating :rating="dish.rating" :count="dish.ratingCount" /><span v-if="dish.commentCount !== undefined">{{ dish.commentCount }} 条评价</span></span>
          </button>
        </li>
      </ol>
      <div v-else-if="!activeStall" class="food-grid">
        <UCard v-for="stall in shownStalls" :key="stall.id" as="button" type="button" variant="outline" class="food-dish food-stall" :ui="{ body: 'p-0 sm:p-0' }" :aria-label="`查看${stall.name}的菜单`" @click="showStall(stall)">
          <div class="food-card-layout">
          <div class="food-card-copy">
            <h3>{{ stall.name }}</h3>
            <p class="food-dish-location" :title="stall.address || stall.floorName">{{ stall.address || stall.floorName }} · {{ categoryLabels[stall.primaryCategory] || '其他' }}</p>
            <div class="food-dish-bottom"><FoodRating :rating="stall.rating" :count="stall.ratingCount" count-label="次评分" /></div>
            <span class="food-shop-link">查看菜单 <UIcon name="i-lucide-arrow-right" aria-hidden="true" /></span>
          </div>
          <FoodImage :src="media(stall.derivedCover?.thumbnailUrl)" :alt="`${stall.name}的菜品封面`" class="food-thumb" />
          </div>
        </UCard>
      </div>
      <div v-else class="food-shop-menu" aria-label="店内菜单">
        <button v-for="dish in shownDishes" :key="dish.id" type="button" class="food-menu-item" :aria-label="`查看${dish.name}的菜品详情和评价`" @click="showDish(dish.id)">
          <span class="food-menu-copy"><span class="food-menu-name">{{ dish.name }}</span><FoodRating :rating="dish.rating" :count="dish.ratingCount" /></span>
          <span class="food-price">{{ foodPrice(dish) }}</span>
          <FoodImage :src="media(dish.cover?.thumbnailUrl)" :alt="dish.name" />
        </button>
      </div>
      <div v-if="hasMore" class="food-more"><UButton variant="outline" color="neutral" :loading="loading" @click="loadMore">{{ tab === 'menu' ? `显示更多（已展示 ${Math.min(visibleCount, menuCount)} / ${menuCount}）` : '加载更多' }}</UButton></div>
      </div>
    </template>
    <noscript>请启用 JavaScript 以读取最新菜单与评价。</noscript>
    <div class="food-footnote">菜单持续整理中，未收录不代表没有售卖。评价是同学的个人体验，可结合日期与评分人数参考。</div>

    <UModal v-model:open="detailOpen" :title="detail?.name || '菜品详情'" :description="detail?.locationText || '查看菜品信息与同学评价'" :ui="{ content: 'max-w-2xl', body: 'overflow-y-auto' }">
      <template #close="{ ui }"><UButton :class="ui.close()" color="neutral" variant="ghost" icon="i-lucide-x" aria-label="关闭菜品详情" /></template>
      <template #body>
        <div class="food-detail">
          <USkeleton v-if="detailLoading" class="food-detail-skeleton" />
          <div v-else-if="detailError" class="food-state" role="alert"><p>{{ detailError }}</p><UButton variant="soft" @click="showDish(selectedId)">重新加载菜品</UButton></div>
          <template v-else-if="detail">
            <button v-if="detail.cover" class="food-detail-cover" type="button" aria-label="放大菜品图片" @click="preview(media(detail.cover.displayUrl))"><FoodImage :src="media(detail.cover.mediumUrl)" :alt="detail.name" /></button>
            <div class="food-detail-summary"><span class="food-detail-price">{{ foodPrice(detail) }}</span><FoodRating :rating="detail.rating" :count="detail.ratingCount" /></div>
            <div v-if="detail.tags.length" class="food-tags"><UBadge v-for="tag in detail.tags" :key="tag" variant="subtle" color="neutral">{{ tag }}</UBadge></div>
            <p v-if="detail.description" class="food-description">{{ detail.description }}</p>
          </template>
          <USeparator class="my-5" />
          <h3 class="food-detail-title">同学评价</h3>
          <p class="food-detail-hint">展示审核通过的评论；评分为发布评论时的记录。</p>
          <div v-if="commentsError" class="food-state" role="alert"><span>{{ commentsError }}</span><UButton variant="soft" @click="loadComments(Boolean(commentsCursor))">重试评价</UButton></div>
          <USkeleton v-if="commentsLoading && !comments.length" class="food-comment-skeleton" />
          <p v-else-if="!comments.length && !commentsError" class="food-no-comments">这道菜还没有公开评价。</p>
          <FoodReviews :items="comments" :api-base="apiBase" @preview="preview" />
          <div v-if="commentsCursor" class="food-more"><UButton variant="outline" color="neutral" :loading="commentsLoading" @click="loadComments(true)">更多评价</UButton></div>
        </div>
      </template>
      <template #footer><span class="food-detail-hint">想分享用餐体验？可在「吃在武科」小程序中评分、发表评价。</span></template>
    </UModal>
    <UModal v-model:open="previewOpen" title="图片预览" :ui="{ content: 'max-w-4xl' }"><template #close="{ ui }"><UButton :class="ui.close()" color="neutral" variant="ghost" icon="i-lucide-x" aria-label="关闭图片预览" /></template><template #body><img class="food-preview" :src="previewUrl" alt="放大的菜品或评价图片"></template></UModal>
  </section>
</template>

<style scoped>
.food-directory { container-type: inline-size; color: var(--ui-text); font-family: var(--font-sans); line-height: 1.5; }
.food-source { display: flex; flex-wrap: wrap; align-items: center; gap: .6rem; font-size: .8rem; color: var(--ui-text-muted); margin-bottom: .85rem; }
.food-scopes { display: flex; flex-wrap: wrap; gap: .5rem; }
.food-scope-note { display: flex; align-items: center; flex-wrap: wrap; gap: .35rem; color: var(--ui-text-muted); font-size: .75rem; margin: .65rem 0 .85rem; }
.food-tabs { margin: 0 0 .85rem; }
.food-filters { display: grid; grid-template-columns: minmax(0, 1fr) 11rem 9rem; gap: .5rem; }
.food-filters-menu { grid-template-columns: minmax(0, 1fr) 9rem; }
/* A short menu must still leave enough document height to align its heading below the sticky navigation. */
.food-shop-view { min-height: calc(100svh - 6rem); }
.food-shop-header { margin: 0 0 1rem; scroll-margin-top: 6rem; }
.food-shop-header h3 { font-size: 1.2rem; font-weight: 600; margin: .5rem 0 .25rem; }
.food-shop-header p { margin: 0; font-size: .8rem; color: var(--ui-text-muted); }
.food-shop-link { display: inline-flex; align-items: center; gap: .4rem; margin-top: .65rem; font-size: .75rem; color: var(--ui-primary); }
.food-shop-menu { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .7rem; }
.food-menu-item { display: grid; grid-template-columns: minmax(0, 1fr) 46%; grid-template-rows: 1fr auto; align-items: center; gap: .3rem .7rem; padding: .65rem; width: 100%; min-width: 0; text-align: left; cursor: pointer; border: 1px solid var(--ui-border); border-radius: .5rem; }
.food-menu-item:hover { background: var(--ui-bg-muted); }
.food-menu-item:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 2px; }
.food-menu-copy { min-width: 0; }
.food-menu-name { display: block; color: var(--ui-text-highlighted); font-size: .95rem; font-weight: 600; margin-bottom: .4rem; overflow-wrap: anywhere; }
.food-menu-item .food-price { margin: 0; grid-column: 1; align-self: start; }
.food-menu-item .food-image { grid-column: 2; grid-row: 1 / span 2; }
.food-search, .food-window-select, .food-sort-select { width: 100%; min-width: 0; }
.food-list-heading { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin: .65rem 0; min-height: 1.75rem; font-size: .75rem; color: var(--ui-text-muted); }
.food-grid, .food-skeleton-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .7rem; }
.food-dish { text-align: left; width: 100%; min-width: 0; cursor: pointer; transition: background .15s, box-shadow .15s; background: var(--ui-bg); }
.food-dish:hover { background: var(--ui-bg-muted); box-shadow: 0 0 0 1px var(--ui-primary); }
.food-dish:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 3px; }
.food-card-layout { display: grid; grid-template-columns: minmax(0, 1fr) 46%; align-items: center; gap: .7rem; padding: .65rem; }
.food-thumb { border-radius: .4rem; }
.food-card-copy { min-width: 0; padding: .1rem 0 .1rem .1rem; }
.food-card-copy h3 { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; font-family: inherit; font-size: .9rem; font-weight: 600; line-height: 1.5; margin: 0; color: var(--ui-text-highlighted); }
.food-price { font-size: .825rem; color: var(--ui-text-highlighted); display: block; font-weight: 550; margin-top: .3rem; }
.food-dish-location { color: var(--ui-text-muted); font-size: .7rem; margin: .3rem 0 !important; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.food-dish-bottom { margin-top: .45rem; }
.food-dish-bottom, .food-detail-summary { display: flex; justify-content: space-between; align-items: center; gap: .5rem; flex-wrap: wrap; }
.food-ranking { list-style: none; margin: 0; padding: 0; }
.food-ranking li + li { border-top: 1px solid var(--ui-border); }
.food-rank-row { display: grid; grid-template-columns: 2.5rem minmax(7rem, 10rem) minmax(0, 1fr) 8rem; align-items: center; gap: 1rem; width: 100%; padding: .9rem .5rem; text-align: left; cursor: pointer; border-radius: .5rem; }
.food-rank-row:hover { background: var(--ui-bg-muted); }
.food-rank-row:focus-visible { outline: 2px solid var(--ui-primary); outline-offset: 2px; }
.food-rank-number { color: var(--ui-text-dimmed); font-size: 1.55rem; font-weight: 750; font-variant-numeric: tabular-nums; text-align: center; letter-spacing: -.04em; white-space: nowrap; }
.food-rank-top .food-rank-number { color: var(--ui-primary); }
.food-rank-number[data-rank='1'] { font-size: 1.9rem; }
.food-rank-top { background: color-mix(in srgb, var(--ui-primary) 4%, transparent); }
.food-rank-copy { min-width: 0; }
.food-rank-name { display: block; color: var(--ui-text-highlighted); font-size: .95rem; font-weight: 600; line-height: 1.5; }
.food-rank-location { display: block; margin: .35rem 0; font-size: .75rem; color: var(--ui-text-muted); }
.food-rank-rating { display: flex; flex-direction: column; align-items: flex-end; gap: .2rem; font-size: .7rem; color: var(--ui-text-muted); }
.food-rank-rating :deep(strong) { font-size: 1.3rem; }
.food-social-feed { max-width: 35rem; margin: .75rem auto 0; }
.food-more { display: flex; justify-content: center; margin-top: 1.5rem; }
.food-state { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .7rem; text-align: center; border: 1px dashed var(--ui-border); border-radius: .6rem; padding: 2.5rem 1rem; margin: 1rem 0; }
.food-state p { margin: 0; font-size: .95rem; font-weight: 550; }
.food-state > span { color: var(--ui-text-muted); font-size: .8rem; }
.food-state-icon { font-size: 1.5rem !important; }
.food-skeleton { height: 9rem; }
.food-footnote { color: var(--ui-text-muted); font-size: .75rem; line-height: 1.8; padding-top: 1.25rem; margin-top: 1.5rem; border-top: 1px solid var(--ui-border); }
.food-detail-cover { display: block; width: 100%; cursor: zoom-in; margin-bottom: 1.25rem; }
.food-detail-cover .food-image { width: 100%; }
.food-detail-price { font-size: 1.2rem; font-weight: 600; }
.food-tags { display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .8rem; }
.food-description { color: var(--ui-text-muted); font-size: .85rem; line-height: 1.8; margin-top: .9rem; }
.food-detail-title { font-size: 1rem; font-weight: 600; }
.food-detail-hint { color: var(--ui-text-muted); font-size: .75rem; line-height: 1.6; margin: .35rem 0 1rem; }
.food-no-comments { color: var(--ui-text-muted); font-size: .85rem; padding: 1.5rem 0; }
.food-detail-skeleton { height: 15rem; }
.food-comment-skeleton { height: 7rem; }
.food-preview { display: block; max-height: 70vh; max-width: 100%; margin: auto; object-fit: contain; }
@container (max-width: 38rem) {
  .food-grid, .food-skeleton-grid, .food-shop-menu { grid-template-columns: 1fr; }
  .food-filters { grid-template-columns: minmax(0, 1fr) 9rem; }
  .food-search { grid-column: 1 / -1; }
  .food-filters-menu .food-search { grid-column: auto; }
  .food-rank-row { grid-template-columns: 1.8rem 6.5rem minmax(0, 1fr); gap: .65rem; padding: .85rem 0; }
  .food-rank-number, .food-rank-image { grid-row: 1 / span 2; }
  .food-rank-rating { grid-column: 3; flex-direction: row; align-items: baseline; flex-wrap: wrap; margin-top: -.25rem; gap: .25rem .5rem; }
  .food-rank-rating :deep(strong) { font-size: 1rem; }
  .food-rank-rating > :last-child:not(:first-child) { font-size: .65rem; }
  .food-rank-number { font-size: 1.2rem; }
  .food-rank-number[data-rank='1'] { font-size: 1.5rem; }
  .food-rank-name { font-size: .85rem; }
  .food-rank-location { font-size: .7rem; margin: .2rem 0; }
}
@container (max-width: 23rem) {
  .food-grid { gap: .55rem; }
  .food-card-layout { gap: .6rem; padding: .6rem; }
  .food-rank-row { grid-template-columns: 2rem 5.75rem minmax(0, 1fr); gap: .5rem; }
}
</style>
