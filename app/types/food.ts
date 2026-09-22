export interface Canteen { id: string; name: string; shortName: string; location: string; description: string }
export interface FoodCover { mediaId: string; thumbnailUrl: string; mediumUrl: string; displayUrl: string }
export interface FoodStall {
  id: string; canteenId: string; floorId: string; floorName: string; name: string
  primaryCategory: string; description: string; address: string; openTime: string
  rating: number | null; ratingCount: number; derivedCover: FoodCover | null
}
export interface Dish {
  id: string; canteenId: string; stallId: string; name: string; price: number; unit: string
  category: string; tags: string[]; description: string; sortOrder: number
  canteenName: string; floorName: string; stallName: string; locationText: string
  rating: number | null; ratingCount: number; cover: FoodCover | null
  averageRating?: number; commentCount?: number; rankScore?: number
}
export interface FoodComment {
  id: string; dishId: string; content: string; ratingSnapshot: number; createdAt: number
  authorLabel: string; authorAvatarFileId: string; images: string[]; imageDisplayUrls: string[]
  dishName?: string; locationText?: string
}
export interface FoodPage<T> { items: T[]; nextCursor?: string; hasMore?: boolean }
