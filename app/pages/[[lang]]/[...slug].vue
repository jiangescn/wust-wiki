<script setup lang="ts">
// Docus 5.13.0 page shell with blog body rendering and extracted article aside slots.
import { blogProseComponents } from '~/utils/blog-prose'
import type { ButtonProps } from '@nuxt/ui'
import type { ContentNavigationItem, Collections, DocsCollectionItem } from '@nuxt/content'
import { findPageHeadline } from '@nuxt/content/utils'

definePageMeta({
  layout: 'docs',
})

const route = useRoute()
const { locale, isEnabled, t } = useDocusI18n()
const { isOpen } = useAssistant()
const appConfig = useAppConfig()
const navigation = inject<Ref<ContentNavigationItem[]>>('navigation')
const collectionName = computed(() => isEnabled.value ? `docs_${locale.value}` : 'docs')

const [{ data: page }, { data: surround }] = await Promise.all([
  useAsyncData(`wiki-doc:${route.path}`, () => queryCollection(collectionName.value as keyof Collections).path(route.path).first() as Promise<DocsCollectionItem>),
  useAsyncData(`wiki-doc:${route.path}:surround`, () => {
    return queryCollectionItemSurroundings(collectionName.value as keyof Collections, route.path, {
      fields: ['description'],
    })
  }),
])

if (!page.value) {
  throw createError({ statusCode: 404, statusMessage: 'Page not found', fatal: true })
}

const title = page.value.seo?.title || page.value.title
const description = page.value.seo?.description || page.value.description

const headline = ref(findPageHeadline(navigation?.value, page.value?.path))
const breadcrumbs = computed(() => findPageBreadcrumbs(navigation?.value, page.value?.path || ''))

useSeo({
  title,
  description,
  type: 'article',
  modifiedAt: (page.value as unknown as Record<string, unknown>).modifiedAt as string | undefined,
  breadcrumbs,
})
watch(() => navigation?.value, () => {
  headline.value = findPageHeadline(navigation?.value, page.value?.path) || headline.value
})

defineOgImage('Docs', {
  headline: headline.value,
  title: title?.slice(0, 60),
  description: formatOgDescription(title, description),
})

const github = computed(() => appConfig.github ? appConfig.github : null)

// Reuse the showcase's rehype-meta-slots output; ordinary documents use Blog-prefixed components.
const articleAsideSlots = computed(() => Object.fromEntries(
  Object.entries((page.value?.meta?.slots || {}) as Record<string, {
    type: 'minimark'
    value: unknown[]
    props?: { title?: string }
  }>).filter(([name]) => name.startsWith('aside-')),
))

const editLink = computed(() => {
  if (!github.value) {
    return
  }

  return [
    github.value.url,
    'edit',
    github.value.branch,
    github.value.rootDir,
    'content',
    `${page.value?.stem}.${page.value?.extension}`,
  ].filter(Boolean).join('/')
})

// Add the page path to the prerender list
addPrerenderPath(`/raw${route.path}.md`)
</script>

<template>
  <UPage
    v-if="page"
    :ui="isOpen ? { center: 'lg:col-span-10' } : undefined"
  >
    <UPageHeader
      :title="page.title"
      :description="page.description"
      :headline="headline"
      :ui="{
        wrapper: 'flex-row items-center flex-wrap justify-between',
      }"
    >
      <template #links>
        <UButton
          v-for="(link, index) in ((page as DocsCollectionItem & { links?: ButtonProps[] }).links || [])"
          :key="index"
          size="sm"
          v-bind="link"
        />

        <DocsPageHeaderLinks />
      </template>
    </UPageHeader>

    <UPageBody>
      <DocsArticleAside :slots="articleAsideSlots" class="lg:hidden" />
      <div class="blog-components wiki-prose">
      <ContentRenderer
        v-if="page"
        :value="page"
        :components="blogProseComponents"
        :prose="false"
        class="article md-tech"
        tag="article"
      />
      </div>

      <USeparator v-if="github">
        <div
          class="flex items-center gap-2 text-sm text-muted"
        >
          <UButton
            variant="link"
            color="neutral"
            :to="editLink"
            target="_blank"
            icon="i-lucide-pen"
            :ui="{ leadingIcon: 'size-4' }"
          >
            {{ t('docs.edit') }}
          </UButton>
          <template v-if="github?.url">
            <span>{{ t('common.or') }}</span>
            <UButton
              variant="link"
              color="neutral"
              :to="`${github.url}/issues/new/choose`"
              target="_blank"
              icon="i-lucide-alert-circle"
              :ui="{ leadingIcon: 'size-4' }"
            >
              {{ t('docs.report') }}
            </UButton>
          </template>
        </div>
      </USeparator>
      <UContentSurround :surround="surround" />
    </UPageBody>

    <template
      v-if="!isOpen"
      #right
    >
      <div class="wiki-doc-aside">
        <DocsAsideRight :page="page" class="wiki-doc-toc" />
        <DocsArticleAside :slots="articleAsideSlots" class="hidden lg:grid" />
      </div>
    </template>
  </UPage>
</template>

<style scoped>
@media (min-width: 1024px) {
  .wiki-doc-aside { min-width: 0; align-self: start; }
  .wiki-doc-aside > .wiki-article-aside { margin-top: 1rem; }
  /* Long directories follow the page, without a second scroll area. */
  .wiki-doc-aside :deep(.wiki-doc-toc > nav) { position: static; max-height: none; overflow: visible; }
  .wiki-doc-aside :deep(.wiki-doc-toc [data-slot="content"]) { overflow: visible; }
}
</style>
