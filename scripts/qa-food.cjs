// Requires Playwright and Edge. Run against dev or proxy-enabled static preview.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { mkdir } = require('node:fs/promises');
const base = process.env.WIKI_QA_URL || 'http://127.0.0.1:4187';

(async () => {
  await mkdir('.cache/food-qa', { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    page.setDefaultTimeout(20000);
    const errors = [];
    const menuRequests = [];
    page.on('request', request => { if (/\/stalls\/[^/?]+\/dishes/.test(request.url())) menuRequests.push(request.url()); });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', msg => { if (/hydration|Failed to resolve component/i.test(msg.text())) errors.push(msg.text()); });
    const waitCards = () => page.locator('.food-dish').first().waitFor();
    const api = async path => {
      const response = await page.request.get(base + '/api/food/' + path);
      assert.equal(response.status(), 200, path);
      return (await response.json()).data;
    };
    const overflow = async () => assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), false, 'whole-page overflow');
    await page.goto(base + '/life/food');
    await waitCards();
    const canteens = (await api('canteens')).sort((a, b) => Number(b.id === 'canteen-nanyuan') - Number(a.id === 'canteen-nanyuan'));
    assert.equal(await page.locator('.food-scopes button').first().innerText(), '南苑食堂');
    assert.equal(await page.getByRole('button', { name: '南苑食堂', exact: true }).getAttribute('aria-pressed'), 'true');
    const shops = await api('stalls/feed?canteenId=' + encodeURIComponent(canteens[0].id));
    assert.ok(shops.length > 12);
    assert.equal(menuRequests.length, 0, 'menus load only after selecting a shop');
    assert.deepEqual(await page.locator('.food-card-copy h3').allTextContents(), shops.slice(0, 12).map(shop => shop.name));
    assert.equal(await page.locator('.food-stall .food-rating-stars').count(), 12);
    const starWidths = await page.locator('.food-stall .food-rating-stars > span').evaluateAll(nodes => nodes.map(node => parseFloat(node.style.width)));
    starWidths.forEach((width, index) => assert.ok(Math.abs(width - (shops[index].rating ?? 0) / 5 * 100) < .001, 'fractional stars match the rating'));
    assert.ok((await page.locator('.food-thumb img').evaluateAll(nodes => nodes.map(node => node.src))).every(src => src.endsWith('/thumbnail')), 'cards use small thumbnails');
    assert.equal(await page.locator('.food-dish').count(), 12);
    await page.getByRole('button', { name: /显示更多/ }).click();
    assert.equal(await page.locator('.food-dish').count(), 24);
    // Search the complete scoped catalog, including entries beyond the first batch.
    const search = page.getByRole('textbox', { name: '搜索店铺', exact: true });
    await search.fill(shops[shops.length - 1].name);
    await page.getByRole('button', { name: `查看${shops[shops.length - 1].name}的菜单`, exact: true }).first().waitFor();
    await search.fill('没有此菜品-QA-EMPTY');
    await page.getByText('没有找到符合条件的店铺', { exact: true }).waitFor();
    await page.getByRole('button', { name: '清除筛选' }).click();
    await page.getByRole('combobox', { name: '筛选楼层' }).click();
    const option = page.getByRole('option').nth(1);
    const label = await option.innerText();
    await option.click();
    const floorNames = shops.filter(shop => shop.floorName === label.trim()).map(shop => shop.name);
    assert.ok((await page.locator('.food-card-copy h3').allTextContents()).every(name => floorNames.includes(name)));
    await page.getByRole('combobox', { name: '筛选楼层' }).click();
    await page.getByRole('option', { name: '全部楼层', exact: true }).click();
    await overflow();
    const columns = await page.locator('.food-grid').evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length);
    assert.equal(columns, 2, 'desktop catalog keeps two columns for a clear reading path');
    const cardParts = await page.locator('.food-dish').first().evaluate(el => {
      const copy = el.querySelector('.food-card-copy').getBoundingClientRect();
      const image = el.querySelector('.food-thumb').getBoundingClientRect();
      return { copyRight: copy.right, imageLeft: image.left, imageWidth: image.width, cardWidth: el.getBoundingClientRect().width };
    });
    assert.ok(cardParts.copyRight < cardParts.imageLeft && cardParts.imageWidth / cardParts.cardWidth > .4, 'left text and large right image');
    const assertRatios = async selector => {
      const sizes = await page.locator(selector).evaluateAll(nodes => nodes.map(el => { const r = el.getBoundingClientRect(); return [r.width, r.height]; }));
      assert.ok(sizes.length > 0);
      for (const [width, height] of sizes) assert.ok(Math.abs(width / height - 4 / 3) < .02, `${selector}: ${width} / ${height}`);
      const offsets = await page.locator(selector + ' img').evaluateAll(nodes => nodes.map(img => {
        const image = img.getBoundingClientRect(), frame = img.parentElement.getBoundingClientRect();
        return { top: image.top - frame.top, left: image.left - frame.left, height: image.height - frame.height };
      }));
      for (const offset of offsets) assert.ok(Object.values(offset).every(value => Math.abs(value) < 1), 'image fills frame without article margins');
    };
    await assertRatios('.food-thumb');
    await page.waitForFunction(() => { const image = document.querySelector('.food-thumb img'); return image?.complete && image.naturalWidth > 0; });
    await page.screenshot({ path: '.cache/food-qa/desktop.png', fullPage: true });

    await page.locator('.food-stall').first().click();
    await page.locator('.food-menu-item').first().waitFor();
    assert.equal(await page.locator('.food-shop-menu').evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length), 2);
    await page.waitForFunction(() => { const top = document.querySelector('.food-shop-header').getBoundingClientRect().top; return top >= 80 && top <= 110; });
    assert.equal(menuRequests.length, 1);
    const menu = await api('stalls/' + shops[0].id + '/dishes');
    await page.getByRole('textbox', { name: '搜索店内菜品' }).fill(menu[menu.length - 1].name);
    await page.getByRole('button', { name: `查看${menu[menu.length - 1].name}的菜品详情和评价`, exact: true }).waitFor();
    await page.getByRole('textbox', { name: '搜索店内菜品' }).fill('');
    await page.getByRole('combobox', { name: '菜品排序' }).click();
    await page.getByRole('option', { name: '单价从低到高', exact: true }).click();
    const prices = (await page.locator('.food-menu-item .food-price').allTextContents()).map(text => Number(text.match(/[\d.]+/)[0]));
    assert.deepEqual(prices, [...prices].sort((a, b) => a - b));
    assert.equal(await page.locator('.food-menu-item .food-image').count(), await page.locator('.food-menu-item').count(), 'same layout regardless of photo');
    await assertRatios('.food-menu-item .food-image');
    assert.ok((await page.locator('.food-menu-item img').evaluateAll(nodes => nodes.map(node => node.src))).every(src => src.endsWith('/thumbnail')));
    await page.locator('.food-menu-item').first().click();
    await page.locator('.food-detail-price').waitFor();
    await page.getByRole('button', { name: '关闭菜品详情' }).click();
    await page.getByRole('dialog').waitFor({ state: 'detached' });
    await page.screenshot({ path: '.cache/food-qa/shop-menu.png', animations: 'disabled' });
    await page.getByRole('button', { name: '返回店铺目录' }).click();
    await waitCards();

    await page.getByRole('tab', { name: '口碑排行' }).click();
    await page.locator('.food-rank-row').first().waitFor();
    const ranking = await api('reputation?canteenId=' + canteens[0].id + '&limit=12');
    assert.deepEqual(await page.locator('.food-rank-name').allTextContents(), ranking.items.map(item => item.name));
    assert.deepEqual(await page.locator('.food-rank-number').allTextContents(), ranking.items.map((_item, index) => String(index + 1).padStart(2, '0')));
    await assertRatios('.food-rank-image');
    await page.screenshot({ path: '.cache/food-qa/ranking.png', fullPage: true });
    if (ranking.nextCursor) {
      await page.getByRole('button', { name: '加载更多', exact: true }).click();
      await page.waitForFunction(() => document.querySelectorAll('.food-rank-row').length > 12);
      assert.equal(await page.locator('.food-rank-number').nth(12).innerText(), '13');
    }
    await page.getByRole('tab', { name: '最新评价' }).click();
    await page.locator('[data-food-review]').first().waitFor();
    const feed = await api('comments/feed?canteenId=' + canteens[0].id + '&limit=12');
    assert.deepEqual(await page.locator('.review-text').allTextContents(), feed.items.filter(item => item.content).map(item => item.content));
    const feedBounds = await page.locator('.food-social-feed').boundingBox();
    const directoryBounds = await page.locator('.food-directory').boundingBox();
    assert.ok(feedBounds.width < directoryBounds.width && feedBounds.width <= 561);
    assert.ok(Math.abs(feedBounds.x + feedBounds.width / 2 - directoryBounds.x - directoryBounds.width / 2) < 2);
    if (feed.items.some(item => item.images.length)) await assertRatios('.review-images .food-image');
    await page.screenshot({ path: '.cache/food-qa/reviews.png', fullPage: true });
    if (feed.nextCursor) {
      await page.getByRole('button', { name: '加载更多', exact: true }).click();
      await page.waitForFunction(() => document.querySelectorAll('[data-food-review]').length > 12);
    }
    const image = page.getByRole('button', { name: '查看评价图片 1' }).first();
    if (await image.count()) {
      await image.click();
      await page.waitForFunction(() => { const img = document.querySelector('.food-preview'); return img && img.complete && img.naturalWidth > 0; });
      await page.getByRole('button', { name: '关闭图片预览' }).click();
    }
    await page.locator('.review-dish button').first().click();
    await page.locator('.food-detail-price').waitFor();
    if (await page.locator('.food-detail-cover').count()) await assertRatios('.food-detail-cover .food-image');
    await page.locator('.food-detail .food-comment-skeleton').waitFor({ state: 'detached' });
    assert.ok(await page.locator('.food-detail [data-food-review]').count() > 0);
    await page.waitForFunction(() => getComputedStyle(document.querySelector('[role="dialog"]')).opacity === '1');
    await page.screenshot({ path: '.cache/food-qa/detail.png', animations: 'disabled' });
    await page.getByRole('button', { name: '关闭菜品详情' }).click();

    await page.getByRole('tab', { name: '菜品目录' }).click();
    await waitCards();
    await page.getByRole('button', { name: canteens[1].name, exact: true }).click();
    await waitCards();
    assert.equal(await page.getByRole('button', { name: canteens[1].name, exact: true }).getAttribute('aria-pressed'), 'true');
    await page.setViewportSize({ width: 390, height: 844 });
    await overflow();
    assert.equal(await page.locator('.food-grid').evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length), 1);
    await assertRatios('.food-thumb');
    await page.evaluate(() => scrollTo(0, 0));
    await page.screenshot({ path: '.cache/food-qa/mobile.png', fullPage: true });
    await page.evaluate(() => { localStorage.setItem('nuxt-color-mode', 'dark'); });
    await page.reload();
    await waitCards();
    await page.waitForFunction(() => document.documentElement.classList.contains('dark'));
    await overflow();
    await page.screenshot({ path: '.cache/food-qa/mobile-dark.png', fullPage: true, animations: 'disabled' });
    await page.locator('.food-dish').first().click();
    await page.locator('.food-menu-item').first().waitFor();
    assert.equal(await page.locator('.food-shop-menu').evaluate(el => getComputedStyle(el).gridTemplateColumns.split(' ').length), 1);
    await assertRatios('.food-menu-item .food-image');
    await overflow();
    await page.screenshot({ path: '.cache/food-qa/shop-menu-mobile.png', fullPage: true });
    await page.locator('.food-menu-item').first().click();
    await page.locator('.food-detail-price').waitFor();
    const bounds = await page.getByRole('dialog').boundingBox();
    assert.ok(bounds.x >= 0 && bounds.x + bounds.width <= 391);
    await page.keyboard.press('Escape');
    await page.getByRole('tab', { name: '口碑排行' }).click();
    await page.locator('.food-rank-row').first().waitFor();
    await assertRatios('.food-rank-image');
    await overflow();
    const rankSize = await page.locator('.food-rank-number').first().evaluate(el => ({ height: el.getBoundingClientRect().height, line: parseFloat(getComputedStyle(el).lineHeight) }));
    assert.ok(rankSize.height <= rankSize.line + 1, 'rank stays on a single line on mobile');
    await page.screenshot({ path: '.cache/food-qa/ranking-mobile.png', fullPage: true });
    await page.getByRole('tab', { name: '最新评价' }).click();
    await page.locator('[data-food-review]').first().waitFor();
    await overflow();
    await page.screenshot({ path: '.cache/food-qa/reviews-mobile.png', fullPage: true });
    await page.getByRole('tab', { name: '菜品目录' }).click();
    await waitCards();

    // Controlled failure/empty/race checks are separate from the live-data checks above.
    await page.route('**/api/food/stalls/feed?*', route => route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ error: { message: 'QA 暂时不可用' } }) }));
    await page.getByRole('button', { name: '刷新', exact: true }).click();
    await page.getByText('QA 暂时不可用', { exact: true }).waitFor();
    await page.unroute('**/api/food/stalls/feed?*');
    await page.getByRole('button', { name: '重试', exact: true }).click();
    await waitCards();
    await page.route('**/api/food/comments/feed?*', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ data: { items: [] } }) }));
    await page.getByRole('tab', { name: '最新评价' }).click();
    await page.getByText('这里还没有公开评价', { exact: true }).waitFor();
    await page.unroute('**/api/food/comments/feed?*');
    // Delay the first canteen response until after the second has rendered.
    await page.getByRole('tab', { name: '菜品目录' }).click();
    await waitCards();
    let release;
    const gate = new Promise(resolve => { release = resolve; });
    await page.route('**/api/food/stalls/feed?*', async route => {
      if (new URL(route.request().url()).searchParams.get('canteenId') !== canteens[0].id) return route.continue();
      await gate;
      await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ data: [{ ...shops[0], name: 'QA 过期响应不得出现' }] }) });
    });
    await page.getByRole('button', { name: canteens[1].name, exact: true }).click();
    await waitCards();
    const requested = page.waitForRequest(request => request.url().includes('/api/food/stalls/feed?canteenId=' + canteens[0].id));
    await page.getByRole('button', { name: canteens[0].name, exact: true }).click();
    await requested;
    await page.getByRole('button', { name: canteens[1].name, exact: true }).click();
    await waitCards();
    release();
    await page.waitForTimeout(300);
    assert.equal(await page.getByText('QA 过期响应不得出现', { exact: true }).count(), 0);
    await page.unroute('**/api/food/stalls/feed?*');
    assert.deepEqual(errors, []);
    console.log('PASS: live shop directory/lazy menus/search/floor/sort/pagination, rankings, public reviews, media, detail, scope switch, mobile/dark, failure recovery, empty state and stale-response isolation');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
