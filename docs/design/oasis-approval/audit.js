async page => {
  return await page.evaluate(() => {
    oasisReview.stop();
    const issues = [];
    const overlap = (a, b) => Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left))
      * Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
    for (const screen of oasisReview.screens) {
      oasisReview.select(screen.id);
      const root = document.querySelector('#mount');
      const camera = root.querySelector('[data-camera]');
      const art = [...root.querySelectorAll('.safeArt')];
      const errors = [];
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const node = walker.currentNode;
        if (!node.textContent.trim()) continue;
        const range = document.createRange();
        range.selectNodeContents(node);
        const rect = range.getBoundingClientRect();
        const element = node.parentElement;
        if (rect.width < 1 || rect.height < 1) continue;
        if (camera && overlap(rect, camera.getBoundingClientRect()) > 1) errors.push('camera: ' + node.textContent.trim());
        if (art.some(a => !a.contains(element) && overlap(rect, a.getBoundingClientRect()) > 1)) errors.push('art: ' + node.textContent.trim());
        if (parseFloat(getComputedStyle(element).fontSize) < 11) errors.push('font: ' + node.textContent.trim());
        const container = element.closest('.appContent,.compactContent,.dialog');
        if (container && !element.closest('.scrollContent')) {
          const bounds = container.getBoundingClientRect();
          if (rect.bottom > bounds.bottom + 1 || rect.right > bounds.right + 1) errors.push('clipped: ' + node.textContent.trim());
        }
      }
      for (const element of root.querySelectorAll('.appContent,.agentList,.agentDetail,.card,.moduleTile')) {
        if (element.scrollHeight > element.clientHeight + 2 && getComputedStyle(element).overflowY !== 'auto') errors.push('overflow: ' + element.className);
      }
      for (const element of root.querySelectorAll('.settingsBody,.settingRow')) {
        if (element.scrollWidth > element.clientWidth + 2) errors.push('horizontal-overflow: ' + element.className);
      }
      if (errors.length) issues.push({id: screen.id, errors});
    }
    oasisReview.select('overview');
    return {checked: oasisReview.screens.length, issues};
  });
}
