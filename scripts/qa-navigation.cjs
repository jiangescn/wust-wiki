// Requires Playwright + Edge and a running Wiki dev/static preview.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const base = process.env.WIKI_QA_URL || 'http://127.0.0.1:4178';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    page.setDefaultTimeout(10000);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const ready = () => page.waitForFunction(() => document.querySelector('#__nuxt')?.__vue_app__?.config.globalProperties.$nuxt?.isHydrating === false);
    async function check(expected) {
      // History updates the URL before Nuxt finishes the reactive page switch.
      let links;
      for (let attempt = 0; attempt < 30; attempt++) {
        links = await page.locator('a').evaluateAll(nodes => nodes.filter(el => el.classList.contains('after:bg-primary')).map(el => el.getAttribute('href')));
        if (links.length === 1 && links[0] === expected) break;
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      assert.deepEqual(links, [expected], `Only the current document should be highlighted at ${page.url()}`);
    }
    await page.goto(base + '/campus/anti-fraud', { waitUntil: 'domcontentloaded' });
    await ready();
    await check('/campus/anti-fraud');
    for (const target of ['/campus', '/campus/accommodation', '/campus/anti-fraud', '/study/grades', '/study', '/life/food']) {
      await page.locator(`a[href="${target}"]`).first().click();
      await page.waitForURL(url => url.pathname.replace(/\/$/, '') === target);
      await check(target);
    }
    await page.goBack(); await check('/study');
    await page.goForward(); await check('/life/food');
    assert.deepEqual(errors, []);
    console.log('PASS: one active document on direct load, section/child/cross-section navigation and browser history');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
