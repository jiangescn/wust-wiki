(() => {
  if (window.__academicWechatButtons || location.origin !== 'https://wiki.wustacm.com') return;
  window.__academicWechatButtons = true;
  function attach() {
    if (!/^\/study\/(curriculum|grades)\/?$/.test(location.pathname)) return;
    const image = document.querySelector('.academic-query .scan-panel img[src^="data:image/png;base64,"]');
    if (!image || image.parentElement.querySelector('[data-wiki-wechat]')) return;
    const actions = document.createElement('div');
    actions.dataset.wikiWechat = '';
    actions.style.cssText = 'display:flex;gap:12px;justify-content:center;align-items:center;flex-wrap:wrap;margin:12px 0';
    for (const [mode, label] of [['confirm', '去微信确认'], ['album', '用相册识别']]) {
      const link = document.createElement('a');
      link.href = 'wiki-academic://' + mode;
      link.textContent = label;
      link.style.cssText = 'border:1px solid currentColor;border-radius:6px;padding:7px 12px;color:var(--ui-primary);font-weight:600';
      actions.append(link);
    }
    image.parentElement.append(actions);
  }
  attach();
  new MutationObserver(attach).observe(document.body, {childList:true,subtree:true,attributes:true,attributeFilter:['src']});
})();
