// Optional browser integration check: requires Playwright and an installed Edge.
// Start the dev/static server first; set WIKI_QA_URL to its origin.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const base = process.env.WIKI_QA_URL || 'http://127.0.0.1:4178';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, permissions: ['clipboard-read', 'clipboard-write'] });
    const page = await context.newPage();
    const errors = [], warnings = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (/hydration|Failed to resolve|Missing required prop/i.test(message.text())) warnings.push(message.text()); });
    async function visit(route) {
      const response = await page.goto(base + route, { waitUntil: 'domcontentloaded' });
      assert.equal(response.status(), 200);
      await page.waitForFunction(() => document.querySelector('#__nuxt')?.__vue_app__?.config.globalProperties.$nuxt?.isHydrating === false);
    }
    await visit('/coder/');
    assert.equal(await page.locator('.lab-list > .card').count(), 20);
    assert.equal(await page.locator('h1').count(), 1);
    const linux = page.locator('#lab-Linux');
    assert.equal(await linux.locator('.face').evaluate(el => getComputedStyle(el).transitionDuration), '0.3s');
    await linux.hover();
    await page.waitForFunction(() => getComputedStyle(document.querySelector('#lab-Linux .face')).transform.startsWith('matrix3d(-1'));
    assert.equal(await linux.locator('.face').evaluate(el => getComputedStyle(el).backfaceVisibility), 'hidden');
    await linux.locator('.back .tip').click();
    await page.waitForFunction(async () => await navigator.clipboard.readText() === '973640471');
    assert.equal(await page.locator('#lab-3G a').filter({ hasText: '培养计划' }).getAttribute('href'), 'https://wiki.cooo.site/coder/plan-mobile');
    async function shuffle(selector) {
      const old = await page.locator(selector).evaluateAll(nodes => nodes.map(el => el.id));
      await page.locator('.shuffle-btn').click();
      await page.waitForFunction(sel => document.querySelectorAll(`${sel}.v-move`).length > 0, selector);
      assert.notDeepEqual(await page.locator(selector).evaluateAll(nodes => nodes.map(el => el.id)), old);
    }
    await shuffle('.lab-list > .card');
    await page.locator('.coder-gulid').hover();
    await page.locator('.tippy-box .qrcode .svg-container svg').waitFor();
    assert.equal(await page.locator('.qrcode a').getAttribute('href'), 'https://pd.qq.com/g/xiyoumanong');
    fs.mkdirSync('.cache', { recursive: true });
    await page.screenshot({ path: '.cache/xupt-labs-desktop.png', animations: 'disabled' });
    await visit('/coder/blog?shuffle=false');
    assert.equal(await page.locator('.blogs > .card').count(), 35);
    const blogs = JSON.parse(fs.readFileSync('app/data/coder/blog.json', 'utf8'));
    assert.equal(await page.locator('.blogs > .card').first().getAttribute('id'), `blog-${encodeURIComponent(blogs[0].link)}`);
    const feed = blogs.find(item => item.feed);
    const feedCard = page.locator(`[id=${JSON.stringify(`blog-${encodeURIComponent(feed.link)}`)}]`);
    await feedCard.hover();
    await page.waitForFunction(id => Number(getComputedStyle(document.getElementById(id).querySelector('.avatar')).opacity) <= 0.21, `blog-${encodeURIComponent(feed.link)}`);
    await feedCard.locator('.links > span.link').click();
    await page.waitForFunction(async value => await navigator.clipboard.readText() === value, feed.feed);
    await shuffle('.blogs > .card');
    await page.screenshot({ path: '.cache/xupt-blogs-desktop.png', animations: 'disabled' });
    for (const route of ['/coder/', '/coder/blog']) {
      await page.setViewportSize({ width: 390, height: 844 });
      await visit(route);
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await page.emulateMedia({ colorScheme: 'dark' });
      await page.waitForFunction(() => document.documentElement.classList.contains('dark'));
      await page.screenshot({ path: `.cache/xupt-${route.includes('blog') ? 'blogs' : 'labs'}-mobile-dark.png`, animations: 'disabled' });
    }
    const touch = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true });
    const mobile = await touch.newPage();
    await mobile.goto(base + '/coder/', { waitUntil: 'domcontentloaded' });
    await mobile.waitForFunction(() => document.querySelector('#__nuxt')?.__vue_app__?.config.globalProperties.$nuxt?.isHydrating === false);
    await mobile.locator('#lab-Linux').tap();
    await mobile.waitForFunction(() => getComputedStyle(document.querySelector('#lab-Linux .face')).transform.startsWith('matrix3d(-1'));
    await touch.close();
    await visit('/');
    assert.equal(await page.locator('.wiki-entry').count(), 15);
    await page.locator('.wiki-entry[href="/coder/blog"]').click();
    await page.locator('.blogs > .card').first().waitFor();
    await visit('/overview');
    assert.ok(await page.locator('main h1').count());
    console.log(JSON.stringify({ errors, warnings }));
    assert.deepEqual(errors, []); assert.deepEqual(warnings, []);
    console.log('PASS: original 3D flip, hover fades, animated reorder, clipboard, QR dropdown, links, dark/mobile and both routes');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
