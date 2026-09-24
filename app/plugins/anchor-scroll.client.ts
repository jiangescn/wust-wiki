import type { RouterConfig } from 'nuxt/schema'

export default defineNuxtPlugin(() => {
  const router = useRouter()
  const options: typeof router.options & Pick<RouterConfig, 'scrollBehaviorType'> = router.options
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
  const updateBehavior = () => {
    options.scrollBehaviorType = reducedMotion.matches ? 'auto' : 'smooth'
  }

  updateBehavior()
  reducedMotion.addEventListener('change', updateBehavior)
  if (import.meta.hot) {
    import.meta.hot.dispose(() => reducedMotion.removeEventListener('change', updateBehavior))
  }
})
