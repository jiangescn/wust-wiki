// Requires Playwright + Edge and a running Wiki dev/static preview.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const base = process.env.WIKI_QA_URL || 'http://127.0.0.1:4190';
const output = '.cache/nearby-qa';

(async () => {
  const { nearbyDefaultCampuses: nearbyCampuses, nearbyPlaces } = await import('../app/data/nearby.ts');
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const errors = [];
  const warnings = new Set();
  const responses = [];
  const monitor = page => {
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'warning') warnings.add(message.text());
      if (message.type() === 'error' && /hydration|resolve component/i.test(message.text())) errors.push(message.text());
    });
    page.on('response', response => {
      if (response.url().includes('tiles.openfreemap.org')) responses.push({ status: response.status(), url: response.url() });
    });
  };
  const ready = page => page.locator('.nearby-map[data-map-state="ready"]').waitFor({ timeout: 60000 });
  const stopped = page => page.locator('.nearby-map[data-map-moving="false"]').waitFor();
  const settled = page => page.locator('.nearby-map[data-map-settled="true"]').waitFor({ timeout: 60000 });
  async function attributionToggle(page) {
    const inner = page.locator('.maplibregl-ctrl-attrib-inner');
    const toggle = page.locator('.maplibregl-ctrl-attrib-button');
    assert.equal(await inner.isVisible(), false, 'Attribution should start collapsed');
    await toggle.click();
    assert.equal(await inner.isVisible(), true, 'Attribution should expand on click');
    await toggle.focus();
    await page.keyboard.press('Enter');
    assert.equal(await inner.isVisible(), false, 'Attribution should collapse with the keyboard');
  }
  async function screenshot(page, file) {
    await settled(page);
    await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
    await page.screenshot({ path: `${output}/${file}`, fullPage: true });
  }
  async function select(page, id, name, animated = true) {
    await page.locator(`[data-place-id="${id}"]`).click();
    await page.locator(`[data-place-id="${id}"][aria-pressed="true"]`).waitFor();
    if (animated) await page.locator('.nearby-map[data-map-moving="true"]').waitFor();
    await stopped(page);
    assert.equal(await page.locator('.maplibregl-popup-content').textContent(), name);
    assert.equal(await page.locator('.nearby-choice[aria-pressed="true"]').count(), 1);
  }
  async function noOverflow(page) {
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), 'Whole page overflows horizontally');
  }
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    monitor(page);
    await page.goto(base + '/life/nearby', { waitUntil: 'domcontentloaded' });
    await ready(page);
    assert.equal(await page.getByText('出行资料（待补充）', { exact: true }).count(), 0);
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    await attributionToggle(page);
    assert.equal(await page.locator('.nearby-place').count(), 15);
    assert.equal(await page.locator('[data-place-id="fuxing-road-metro"], [data-place-id="jiyuqiao-metro"]').count(), 0);
    assert.equal(await page.locator('.nearby-campus').count(), 2);
    assert.equal(await page.locator('.nearby-campus-marker').count(), 2);
    assert.equal(await page.locator('[data-place-id="wust-hongshan"], [data-campus-id="wust-hongshan"]').count(), 0);
    for (const name of ['白沙天街', '江汉路', '东湖绿道', '黄鹤楼', '昙华林', '武汉站', '武昌站', '汉口站', '武汉东站', '天河机场', '黄家湖（武科大）站']) {
      assert.ok((await page.locator('.nearby-list').textContent()).includes(name), `Missing draft destination: ${name}`);
    }
    assert.ok(responses.some(response => response.status === 200 && /\/planet\/.+\.pbf$/.test(response.url)), 'Real map tiles were not loaded');
    for (const provider of ['OpenFreeMap', 'OpenMapTiles', 'OpenStreetMap']) assert.ok((await page.locator('.maplibregl-ctrl-attrib').textContent()).includes(provider));
    await select(page, 'yellow-crane-tower', '黄鹤楼');
    await select(page, 'gude-temple', '古德寺');
    // Interrupt an active flight by selecting another point.
    await page.locator('[data-place-id="botanical-garden"]').click();
    await page.locator('.nearby-map[data-map-moving="true"]').waitFor();
    await select(page, 'hubei-museum', '湖北省博物馆');
    // Clear selection through filtering while retaining the camera, then select a native point.
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('古德寺');
    assert.equal(await page.locator('.nearby-place[aria-pressed="true"]').count(), 0);
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('');
    await settled(page);
    const canvas = page.locator('.maplibregl-canvas');
    const box = await canvas.boundingBox();
    await canvas.click({ position: { x: box.width / 2, y: box.height / 2 } });
    await stopped(page);
    assert.equal(await page.locator('[data-place-id="hubei-museum"]').getAttribute('aria-pressed'), 'true');
    // Isolate the two park points; at zoom 8 they form a cluster. School markers stay.
    await page.getByLabel('地点分类', { exact: true }).selectOption('公园');
    assert.equal(await page.locator('.nearby-place').count(), 2);
    assert.equal(await page.locator('.nearby-campus-marker').count(), 2);
    for (let i = 0; i < 7; i++) {
      await page.locator('.maplibregl-ctrl-zoom-out').click();
      await stopped(page);
    }
    await settled(page);
    const mercatorY = latitude => (1 - Math.log(Math.tan(Math.PI / 4 + latitude * Math.PI / 360)) / Math.PI) / 2;
    const parks = nearbyPlaces.filter(place => place.category === '公园');
    const parkCenter = parks.reduce((sum, place) => [sum[0] + place.coordinates[0] / parks.length, sum[1] + place.coordinates[1] / parks.length], [0, 0]);
    const scale = 512 * 2 ** 8;
    const clusterPosition = {
      x: box.width / 2 + (parkCenter[0] - 114.358889) / 360 * scale,
      y: box.height / 2 + (mercatorY(parkCenter[1]) - mercatorY(30.563889)) * scale,
    };
    await canvas.click({ position: clusterPosition });
    await page.locator('.nearby-map[data-map-moving="true"]').waitFor();
    await stopped(page);
    assert.equal(await page.locator('.nearby-choice[aria-pressed="true"]').count(), 0);
    await page.getByLabel('地点分类', { exact: true }).selectOption('全部');
    await page.locator('[data-place-id="wuhan-university"]').focus();
    await page.keyboard.press('Enter');
    await stopped(page);
    assert.equal(await page.locator('.maplibregl-popup-content').textContent(), '武汉大学');
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('东湖');
    assert.equal(await page.locator('.nearby-place').count(), 3);
    assert.equal(await page.locator('.nearby-place[aria-pressed="true"]').count(), 0);
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('没有这个地方');
    await page.getByText('没有匹配的地点', { exact: true }).waitFor();
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('');
    await page.getByLabel('地点分类', { exact: true }).selectOption('历史建筑');
    assert.equal(await page.locator('.nearby-place').count(), 2);
    await page.getByRole('button', { name: '查看全部', exact: true }).click();
    await stopped(page);
    assert.equal(await page.locator('.maplibregl-popup-content').count(), 0);
    await page.getByLabel('地点分类', { exact: true }).selectOption('全部');
    await page.getByRole('button', { name: '查看全部', exact: true }).click();
    await stopped(page);
    await noOverflow(page);
    await screenshot(page, 'desktop-light.png');
    // Stress the bounded list layout with synthetic copies, without adding fake data.
    const bounded = await page.locator('.nearby-list').evaluate(list => {
      const sample = list.firstElementChild;
      const originalCount = list.children.length;
      for (let i = 0; i < 80; i++) list.append(sample.cloneNode(true));
      const result = list.scrollHeight > list.clientHeight && list.clientHeight <= 440;
      while (list.children.length > originalCount) list.lastElementChild.remove();
      return result;
    });
    assert.ok(bounded, 'Many-item list is not independently bounded');
    // Each WUST campus is an independent, labelled marker; filters retain both default campuses.
    for (const campus of nearbyCampuses) {
      await select(page, campus.id, campus.name);
      assert.equal(await page.locator(`[data-campus-id="${campus.id}"]`).getAttribute('aria-pressed'), 'true');
    }
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('没有这个地方');
    assert.equal(await page.locator('.nearby-campus').count(), 2);
    assert.equal(await page.locator('.nearby-campus-marker').count(), 2);
    assert.equal(await page.locator('[data-place-id="wust-qingshan"]').getAttribute('aria-pressed'), 'true');
    await page.getByRole('textbox', { name: '搜索地点', exact: true }).fill('');
    await page.getByRole('button', { name: '查看全部', exact: true }).click();
    await stopped(page);
    await settled(page);
    await page.locator('[data-campus-id="wust-qingshan"]').click();
    await stopped(page);
    assert.equal(await page.locator('[data-place-id="wust-qingshan"]').getAttribute('aria-pressed'), 'true');
    assert.equal(await page.locator('.maplibregl-popup-content').textContent(), '武汉科技大学（青山校区）');
    await screenshot(page, 'desktop-campus.png');
    // Wiki theme does not change the map; the small map control switches it independently.
    const theme = page.locator('header').getByRole('button', { name: /Switch to dark mode|切换.*深色/i });
    await theme.click();
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    assert.ok(!responses.some(response => response.url.endsWith('/styles/dark')), 'Wiki theme changed the map');
    await screenshot(page, 'desktop-wiki-dark-map-light.png');
    const desktopDarkStyle = page.waitForResponse(response => response.url().endsWith('/styles/dark') && response.status() === 200);
    await page.getByRole('button', { name: '切换为深色地图', exact: true }).click();
    await desktopDarkStyle;
    await ready(page);
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'dark');
    assert.equal(await page.locator('.maplibregl-popup-content').textContent(), '武汉科技大学（青山校区）');
    assert.ok(responses.some(response => response.status === 200 && response.url.endsWith('/styles/dark')), 'Dark map style did not load');
    await select(page, 'botanical-garden', '武汉植物园');
    assert.equal(await page.locator('.nearby-campus-marker').count(), 2);
    await screenshot(page, 'desktop-dark.png');
    await page.locator('header').getByRole('button', { name: /Switch to light mode|切换.*浅色|切换.*亮色/i }).click();
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'dark');
    await page.locator('header').getByRole('button', { name: /Switch to dark mode|切换.*深色/i }).click();
    // Client navigation must dispose and recreate the map.
    await page.locator('a[href="/life/food"]').first().click();
    await page.waitForURL(url => url.pathname === '/life/food');
    await page.locator('.nearby-map').waitFor({ state: 'detached' });
    await page.locator('a[href="/life/nearby"]').first().click();
    await ready(page);
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    await page.reload({ waitUntil: 'domcontentloaded' });
    await ready(page);
    assert.equal(await page.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    assert.ok(await page.locator('html').evaluate(root => root.classList.contains('dark')));
    await noOverflow(page);
    await page.close();

    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
    monitor(mobile);
    await mobile.goto(base + '/life/nearby', { waitUntil: 'domcontentloaded' });
    await ready(mobile);
    await attributionToggle(mobile);
    await select(mobile, 'gude-temple', '古德寺', false);
    assert.equal(await mobile.locator('.nearby-map').getAttribute('data-map-moving'), 'false');
    await noOverflow(mobile);
    const layout = await mobile.locator('.nearby-list').evaluate(list => {
      const map = document.querySelector('.nearby-map').getBoundingClientRect();
      return list.getBoundingClientRect().top >= map.bottom && getComputedStyle(list).gridTemplateColumns.split(' ').length === 2;
    });
    assert.ok(layout, 'Mobile list should be below the map with two columns');
    await screenshot(mobile, 'mobile-light.png');
    await select(mobile, 'wust-huangjiahu', '武汉科技大学（黄家湖校区）', false);
    await screenshot(mobile, 'mobile-campus.png');
    await mobile.locator('header').getByRole('button', { name: /Switch to dark mode|切换.*深色/i }).click();
    assert.equal(await mobile.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    await screenshot(mobile, 'mobile-wiki-dark-map-light.png');
    const mobileDarkStyle = mobile.waitForResponse(response => response.url().endsWith('/styles/dark') && response.status() === 200);
    await mobile.getByRole('button', { name: '切换为深色地图', exact: true }).click();
    await mobileDarkStyle;
    await ready(mobile);
    assert.equal(await mobile.locator('.nearby-map').getAttribute('data-map-theme'), 'dark');
    await noOverflow(mobile);
    await screenshot(mobile, 'mobile-dark.png');
    await mobile.getByRole('button', { name: '切换为亮色地图', exact: true }).focus();
    const mobileLightStyle = mobile.waitForResponse(response => response.url().endsWith('/styles/liberty') && response.status() === 200);
    await mobile.keyboard.press('Enter');
    await mobileLightStyle;
    await ready(mobile);
    assert.equal(await mobile.locator('.nearby-map').getAttribute('data-map-theme'), 'light');
    assert.equal(await mobile.locator('.maplibregl-popup-content').textContent(), '武汉科技大学（黄家湖校区）');
    await mobile.close();

    const offline = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    monitor(offline);
    await offline.route('https://tiles.openfreemap.org/**', route => route.abort());
    await offline.goto(base + '/life/nearby', { waitUntil: 'domcontentloaded' });
    await offline.getByText('地图暂时无法加载', { exact: true }).waitFor({ timeout: 30000 });
    await offline.locator('[data-place-id="gude-temple"]').click();
    assert.equal(await offline.locator('.nearby-selection strong').textContent(), '古德寺');
    assert.ok((await offline.locator('.nearby-selection a').getAttribute('href')).includes('Q10913316'));
    await offline.unroute('https://tiles.openfreemap.org/**');
    await offline.getByRole('button', { name: '重试', exact: true }).click();
    await ready(offline);
    assert.equal(await offline.locator('.maplibregl-popup-content').textContent(), '古德寺');
    await offline.close();
    assert.deepEqual(errors, [], 'Runtime/hydration errors');
    const report = { result: 'PASS', realMapResponses: responses.length, mapHttpFailures: responses.filter(response => response.status >= 400), warnings: [...warnings] };
    fs.writeFileSync(`${output}/report.json`, JSON.stringify(report, null, 2));
    console.log('PASS: real tiles/attribution, native points/clusters, selection and interrupted animation, filters, keyboard, desktop/mobile themes, reduced motion, bounded list, navigation, failure/retry');
    console.log(`Evidence: ${output}; map responses: ${responses.length}; warnings: ${warnings.size}`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
