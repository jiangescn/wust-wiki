(() => {
  function openLink(event) {
    const link = event.target.closest?.('a[href]')
    if (!link || !event.isTrusted) return
    const url = new URL(link.getAttribute('href'), location.href)
    if (!['http:', 'https:'].includes(url.protocol)) return
    if (url.origin === location.origin && url.pathname.replace(/\/$/, '') === location.pathname.replace(/\/$/, '') && url.hash) return
    event.preventDefault()
    event.stopImmediatePropagation()
    // A user gesture routes the destination through the enclosing Android app.
    location.href = 'wikireader://open/?url=' + encodeURIComponent(url.href)
  }
  document.addEventListener('click', openLink, true)

  let playArticle
  window.wikiReaderPrepare = (disableMotion, allowBeforeHydration) => {
    if (document.readyState === 'loading') return false
    const article = document.querySelector('article.md-tech, main.xupt-coder-page')
    if (!article) return allowBeforeHydration
    const nuxt = document.querySelector('#__nuxt')?.__vue_app__?.config.globalProperties.$nuxt
    if ((!nuxt || nuxt.isHydrating) && !allowBeforeHydration) return false
    if (playArticle || disableMotion || typeof IntersectionObserver !== 'function') return true
    const reduced = matchMedia('(prefers-reduced-motion: reduce)')
    if (reduced.matches) return true
    const headingSelector = 'h1,h2,h3,h4,h5,h6'
    const textSelector = 'p,ul,ol,blockquote,dl'
    const sections = new Map()
    let section = 0
    const blocks = article.matches('article') ? article.children : article.querySelectorAll(
      'h1, .center-line.vp-doc, .lab-list > *, .blogs > *, .reference-note, .coder-contribute',
    )
    for (const element of blocks) {
      if (element.matches(headingSelector)) section++
      if (element.matches('hr,.app-component-tools,script,style,[hidden]')) continue
      sections.set(element, section)
    }

    const running = new Set()
    function reveal(visible, held) {
      let activeSection
      let nextDelay = 0
      let animated = 0
      for (const { target, boundingClientRect: rect } of visible.sort(
        (a, b) => a.boundingClientRect.top - b.boundingClientRect.top,
      )) {
        observer.unobserve(target)
        const currentSection = sections.get(target)
        sections.delete(target)
        if (animated >= 8 || rect.top < -32 ||
            (document.activeElement && target.contains(document.activeElement)) ||
            !target.getClientRects().length) continue

        const style = getComputedStyle(target)
        if (style.visibility !== 'visible' || style.display === 'contents') continue
        if (activeSection !== undefined && activeSection !== currentSection) nextDelay += 22
        activeSection = currentSection
        const heading = target.matches(headingSelector)
        const text = target.matches(textSelector) && rect.height < innerHeight * .65
        // Keep tall readers, tables and code editors intact while revealing their card.
        const frames = heading ? [
          { clipPath: 'inset(0 100% 0 0)', translate: '-9px 0' },
          { clipPath: 'inset(0)', translate: '0 0' },
        ] : text ? [
          { clipPath: 'inset(0 0 85% 0)', opacity: .58, translate: '0 5px' },
          { clipPath: 'inset(0)', opacity: 1, translate: '0 0' },
        ] : [
          { opacity: .55, translate: '0 10px', scale: .985 },
          { opacity: 1, translate: '0 0', scale: 1 },
        ]
        const animation = target.animate(frames, {
          delay: Math.min(nextDelay, 320),
          duration: heading ? 420 : text ? 350 : 310,
          easing: 'cubic-bezier(.22,.61,.36,1)',
          fill: 'backwards',
        })
        if (held) {
          animation.pause()
          animation.currentTime = 0
        }
        running.add(animation)
        animation.finished.then(
          () => running.delete(animation),
          () => running.delete(animation),
        )
        animated++
        nextDelay += heading ? 75 : 48
      }
    }
    const observer = new IntersectionObserver(entries => {
      if (!reduced.matches) reveal(entries.filter(entry => entry.isIntersecting), false)
    }, { rootMargin: '0px 0px 56px' })
    const initial = [...sections.keys()].map(target => ({
      target,
      boundingClientRect: target.getBoundingClientRect(),
    })).filter(({ boundingClientRect: rect }) => rect.bottom > 0 && rect.top < innerHeight)
    reveal(initial, true)
    function cancel() {
      observer.disconnect()
      for (const animation of running) animation.cancel()
      sections.clear()
    }
    playArticle = disableMotion => {
      if (disableMotion || reduced.matches) return cancel()
      for (const animation of running) animation.play()
      for (const element of sections.keys()) observer.observe(element)
    }
    reduced.addEventListener('change', event => {
      if (event.matches) cancel()
    })
    return true
  }
  let articlePlayed = false
  window.wikiReaderPlay = disableMotion => {
    if (articlePlayed && !disableMotion) return
    articlePlayed = true
    playArticle?.(disableMotion)
  }

  // Use the original Vue/Tippy actions without depending on hover in WebView.
  const toolTargets = [
    ['figure.md-table', '表格显示方式'],
    ['.mermaid-diagram', '图表显示方式'],
    ['.feed-card', '查看站点简介'],
  ]
  const controls = new WeakMap()
  let activeTool
  document.addEventListener('pointerdown', event => {
    if (!activeTool) return
    const { tip, button } = activeTool
    if (!button.contains(event.target) && !tip.popper.contains(event.target)) tip.hide()
  })
  function tooltipFor(element) {
    const direct = element._tippy || element.parentElement?._tippy
    if (direct) return direct
    return [...element.children].find(child => child._tippy)?._tippy
  }
  function mountTools() {
    for (const [selector, label] of toolTargets) {
      for (const element of document.querySelectorAll(`.blog-components ${selector}`)) {
        const tip = tooltipFor(element)
        if (!tip || tip.state.isDestroyed || controls.has(tip)) continue
        const holder = document.createElement('div')
        holder.className = 'app-component-tools'
        const button = document.createElement('button')
        button.type = 'button'
        button.className = 'app-component-action'
        button.textContent = label
        button.setAttribute('aria-expanded', 'false')
        holder.append(button)
        // Append next to the component so scrolling its table or chart never
        // scrolls the action away. Keep the feed card link directly tappable.
        const reference = tip.reference
        const anchor = reference.contains(element) ? reference : element
        anchor.after(holder)
        const handlers = tip.props
        tip.setProps({
          trigger: 'manual',
          hideOnClick: false,
          placement: 'bottom-end',
          getReferenceClientRect: () => button.getBoundingClientRect(),
          onShow(instance) {
            const result = handlers.onShow(instance)
            if (result !== false) button.setAttribute('aria-expanded', 'true')
            return result
          },
          onHide(instance) {
            const result = handlers.onHide(instance)
            if (result !== false) {
              button.setAttribute('aria-expanded', 'false')
              if (activeTool?.tip === tip) activeTool = undefined
            }
            return result
          },
          onDestroy(instance) {
            holder.remove()
            handlers.onDestroy(instance)
          },
        })
        button.addEventListener('click', () => {
          if (tip.state.isVisible) tip.hide()
          else {
            activeTool?.tip.hide()
            activeTool = { tip, button }
            tip.show()
          }
        })
        controls.set(tip, button)
      }
    }
  }
  document.addEventListener('DOMContentLoaded', () => {
    let frame = 0
    const scan = () => {
      if (frame) return
      frame = requestAnimationFrame(() => {
        frame = 0
        mountTools()
      })
    }
    new MutationObserver(scan).observe(document.querySelector('#__nuxt') || document.body, {
      childList: true,
      subtree: true,
    })
    scan()
    window.addEventListener('load', scan, { once: true })
  })
})()
