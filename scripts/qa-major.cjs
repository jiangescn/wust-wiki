const { chromium } = require('playwright')
const assert = require('node:assert/strict')

;(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true })
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    await page.goto(`${process.env.WIKI_QA_URL || 'http://127.0.0.1:4178'}/campus/major`, { waitUntil: 'networkidle' })
    const cards = page.locator('.major-card')
    assert.equal(await cards.count(), 76)
    assert.equal(await page.locator('.major-grid').count(), 22)
    assert.equal(await page.locator('.major-grid').last().evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length), 5)
    assert.equal(await page.locator('.major-card .banner:visible').count(), 0)
    const first = cards.first()
    await first.hover()
    await page.waitForTimeout(400)
    assert.equal(await first.locator('.back').evaluate(el => getComputedStyle(el).transform), 'matrix(1, 0, 0, 1, 0, 0)')
    assert.equal(await first.locator('a.major-official').getAttribute('href'), 'https://cl.wust.edu.cn/')
    await page.mouse.move(0, 0)
    await first.focus()
    await page.waitForTimeout(400)
    assert.equal(await first.locator('.back').evaluate(el => getComputedStyle(el).transform), 'matrix(1, 0, 0, 1, 0, 0)')
    await page.keyboard.press('Tab')
    assert(await first.locator('a').first().evaluate(el => el === document.activeElement))
    const details = page.locator('details').filter({ has: page.locator('summary', { hasText: '专业备注' }) })
    assert.equal(await details.count(), 22)
    await details.first().locator('summary').click()
    assert(await details.first().locator('table').isVisible())
    for (const width of [390, 768, 1440]) {
      await page.setViewportSize({ width, height: 1000 })
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `page overflow at ${width}`)
      for (const card of await cards.all()) {
        assert(await card.locator('.back').evaluate(el => el.scrollHeight <= el.clientHeight + 1), `back clipped at ${width}`)
      }
    }
    await first.scrollIntoViewIfNeeded()
    await page.mouse.move(0, 0)
    await page.screenshot({ path: '.cache/major-desktop.png' })
    await page.setViewportSize({ width: 390, height: 844 })
    await first.scrollIntoViewIfNeeded()
    await page.screenshot({ path: '.cache/major-mobile.png' })
    assert.deepEqual(errors, [])
    console.log('Major list OK: 76 cards, 22 colleges, original hover, keyboard, official link, preserved tables, 390/768/1440px, no runtime errors.')
  } finally { await browser.close() }
})().catch(error => { console.error(error); process.exitCode = 1 })
