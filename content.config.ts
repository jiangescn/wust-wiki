import { defineContentConfig, defineCollection, z } from '@nuxt/content'

export default defineContentConfig({
  collections: {
    landing: defineCollection({ type: 'page', source: 'index.md' }),
    docs: defineCollection({
      type: 'page',
      source: { include: '**', exclude: ['index.md'] },
      schema: z.object({
        status: z.enum(['draft', 'published']).default('draft'),
        updated: z.string().optional(),
      }),
    }),
  },
})
