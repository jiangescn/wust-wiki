const { chromium } = require('playwright');
const assert = require('node:assert/strict');
(async () => {
 const browser=await chromium.launch({channel:'msedge',headless:true});
 try {
 const p=await browser.newPage({viewport:{width:1280,height:900}});
 await p.route('https://picsum.photos/**',route=>route.fulfill({contentType:'image/svg+xml',body:'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="steelblue"/></svg>'}));
 await p.goto((process.env.WIKI_QA_URL||'http://127.0.0.1:4178')+'/blog-components',{waitUntil:'domcontentloaded'});
 await p.waitForFunction(()=>document.querySelector('#__nuxt')?.__vue_app__?.config.globalProperties.$nuxt?.isHydrating===false);
 await p.waitForFunction(()=>document.querySelector('.badge-icon')?.naturalWidth>0);
 const results=await p.evaluate(()=>({
  badge: [...document.querySelectorAll('.badge-icon')].every(e=>parseFloat(getComputedStyle(e).height)<=32),
  code: [...document.querySelectorAll('.z-codeblock pre')].every(e=>parseFloat(getComputedStyle(e).paddingInlineStart)>=40),
  math: [...document.querySelectorAll('.katex .strut')].every(e=>getComputedStyle(e).display==='inline-block'),
  sidebar: parseFloat(getComputedStyle(document.querySelector('.showcase-aside section')).paddingLeft)>=12,
  key: !!document.querySelector('header .search-keys kbd'),
 }));
 console.log(results);
 assert.ok(Object.values(results).every(Boolean),'All five reported layout areas must pass');
 for(const width of [1024,900,768,390]) {
  await p.setViewportSize({width,height:844});
  assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),`Page overflow at ${width}`);
  assert.ok(await p.locator('.showcase-aside').evaluate(e=>e.scrollWidth<=e.clientWidth),`Sidebar clipping at ${width}`);
 }
 await p.setViewportSize({width:1280,height:900});
 await p.locator('header .search-keys kbd').last().click();
 await p.getByRole('dialog').waitFor();
 await p.keyboard.press('Escape');
 await p.keyboard.press('Control+k');
 await p.getByRole('dialog').waitFor();
 console.log('PASS: badge size, code gutter, KaTeX layout, responsive sidebar and original shortcut keys/search');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
