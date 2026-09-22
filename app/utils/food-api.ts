import { createClient } from '../../vendor/eat-in-wust/client.mjs'
import type { Canteen, Dish, FoodComment, FoodPage, FoodStall } from '~/types/food'

export function createFoodApi(baseUrl: string) {
  const api = createClient({ baseUrl })
  const id = encodeURIComponent
  return {
    canteens: () => api.get<Canteen[]>('/canteens'),
    stalls: (canteenId: string) => api.get<FoodStall[]>('/stalls/feed', { canteenId }),
    stallDishes: (stallId: string) => api.get<Dish[]>(`/stalls/${id(stallId)}/dishes`),
    dish: (dishId: string) => api.get<Dish>(`/dishes/${id(dishId)}`),
    reputation: (canteenId: string, cursor?: string) => api.get<FoodPage<Dish>>('/reputation', { canteenId, cursor, limit: 12 }),
    reviews: (canteenId: string, cursor?: string) => api.get<FoodPage<FoodComment>>('/comments/feed', { canteenId, cursor, limit: 12 }),
    comments: (dishId: string, cursor?: string) => api.get<FoodPage<FoodComment>>(`/dishes/${id(dishId)}/comments`, { cursor, limit: 12 }),
  }
}

// Only controlled public media routes can be embedded, through the same API base.
export function foodMediaUrl(value: string | undefined, baseUrl: string): string {
  if (!value) return ''
  const match = /^\/api\/v1\/(media\/[a-f0-9-]{36}(?:\/(?:thumbnail|medium))?)$/i.exec(value)
  return match ? `${baseUrl.replace(/\/$/, '')}/${match[1]}` : ''
}
export function foodPrice(dish: Pick<Dish, 'price' | 'unit'>): string {
  return `¥${dish.price.toLocaleString('zh-CN', { maximumFractionDigits: 2 })} / ${dish.unit || '份'}`
}
