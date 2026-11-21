async page => {
  const manifest = await (await page.request.get('http://127.0.0.1:8767/oasis-approval/current-controls.json')).json();
  return await page.evaluate(manifest => {
    oasisReview.stop();
    let checks = 0;
    const missing = [];
    const check = (screen, ok, expected) => { checks++; if (!ok) missing.push({screen, expected}); };
    for (const item of manifest) {
      oasisReview.select(item.screen);
      const text = document.querySelector('#mount').innerText;
      for (const sourceLabel of item.labels) {
        const label = sourceLabel.split('\\(')[0].trim();
        check(item.screen, text.includes(label), label);
      }
    }
    const features = {
      duo: ['artwork-source','title-source','artist','previous','play-pause','next','weekday','day','event-title','event-time','event-location','join'],
      player: ['artwork-source','title-source','artist','waveform','seek','elapsed','time-display','extra-control','previous','play-pause','next','volume'],
      'player-volume': ['volume-row','volume','seek'],
      overview: ['seek','today','nearest','event-location','join','claude-title','claude-subtitle','codex-link','soon-open','soon-countdown','soon-complete','soon-completed'],
      'calendar-month': ['weekday','day','event-indicator'],
      inbox: ['unread','observed-time','join','soon-complete','soon-snooze'],
      'soon-list': ['soon-open','soon-countdown','soon-complete','soon-completed'],
      'soon-completed': ['soon-open','soon-repeat','soon-clear'],
      'soon-detail': ['countdown','deadline','reminder-state','delete-direct'],
      'claude-question': ['agent-state','agent-waiting-count','session-meta','waiting-filter','option-description','submit','inbox','settings'],
      'claude-permission': ['permission-preview'],
      'codex-secret': ['secret-answer'],
      queue: ['queue-open'],
      'queue-capsule': ['queue-open'],
      charging: ['battery-glyph'],
      'low-battery': ['battery-glyph','percentage'],
      airpods: ['device-model','ring']
    };
    for (const [id, expected] of Object.entries(features)) {
      oasisReview.select(id);
      for (const feature of expected) check(id, !!document.querySelector('#mount [data-feature="'+feature+'"]'), feature);
    }
    oasisReview.select('duo');
    check('duo', !document.querySelector('#mount .nativeProgress,#mount .timeRow,#mount input[type=range]'), 'В Duo нет полосы времени');
    oasisReview.select('player');
    check('player', document.querySelectorAll('.nativeFive>.nativeMediaButton').length===5, 'Пять кнопок PlayerControl');
    oasisReview.select('inbox');
    check('inbox', !document.querySelector('#mount').innerText.includes('Прочитать всё'), 'Нет придуманного действия Прочитать всё');
    oasisReview.select('charging');
    check('charging', !document.querySelector('#mount [data-feature=percentage]'), 'Charging без процента');
    oasisReview.select('low-power');
    check('low-power', !document.querySelector('#mount [data-feature=percentage]'), 'Low Power Mode без процента');
    oasisReview.select('soon-create');
    check('soon-create', document.querySelectorAll('[data-preset]').length===4, 'Четыре текущих пресета времени');
    oasisReview.select('soon-detail');
    for (const label of ['Готово','+5 мин','Отложить…','Изменить','Удалить']) check('soon-detail',document.querySelector('#mount').innerText.includes(label),label);
    check('soon-delete', !oasisReview.screens.some(s=>s.id==='soon-delete'), 'Нет придуманного подтверждения удаления');
    oasisReview.select('claude-question');
    for (const selector of ['.nativeRequestPager','.nativeQuestionPager','textarea.editor','[data-auto-next]']) check('claude-question', !!document.querySelector(selector),selector);
    oasisReview.select('claude-final');
    check('claude-final', document.querySelector('[data-feature=submit]').textContent.includes('Ответить'), 'Отдельная отправка последнего ответа');
    oasisReview.select('settings-general');
    check('settings-general',document.querySelectorAll('.nativeSlider').length===3,'Hover duration, Notch width, Notch height');
    for (const label of ['None','Playing','Calendar','Overview'])check('settings-general',document.querySelector('#mount').innerText.includes(label),label);
    oasisReview.select('settings-nowPlaying');
    for (const label of ['Monochrome','Colored','Gradient','Favorite','Shuffle','Repeat','Copy','System','Yandex Music','Connect…','Disconnect…']) check('settings-nowPlaying',document.querySelector('#mount').innerText.includes(label),label);
    check('settings-nowPlaying',[...document.querySelectorAll('.nativeTile')].some(t=>t.textContent.includes('Copy')&&t.disabled),'Copy остаётся недоступной');
    oasisReview.select('settings-calendar');
    check('settings-calendar',document.querySelectorAll('.settingRow>input[type=checkbox]').length===2,'Выбор календарей');
    check('settings-calendar',!!document.querySelector('.lockedRow button:disabled'),'Notify when time to leave остаётся недоступной');
    oasisReview.select('settings-claudeCode');
    check('settings-claudeCode',document.querySelectorAll('.nativeThresholds input').length===4,'Четыре порога');
    check('settings-claudeCode',!!document.querySelector('input[type=time]'),'Конец рабочего дня');
    oasisReview.select('overview');
    return {checks, sourceLabels:manifest.reduce((n,x)=>n+x.labels.length,0), missing};
  }, manifest);
}
