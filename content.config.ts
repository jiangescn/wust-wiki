import { defineContentConfig, defineCollection, z } from '@nuxt/content'

export default defineContentConfig({
  collections: {
    landing: defineCollection({ type: 'page', source: 'index.md' }),
    docs: defineCollection({
      type: 'page',
      // Temporarily hide the opening page; keep its Markdown for restoration.
      source: { include: '**', exclude: ['index.md', '0.overview.md'] },
      schema: z.object({
        status: z.enum(['draft', 'published']).default('draft'),
        updated: z.string().optional(),
      }),
    }),
  },
})
