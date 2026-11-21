screens.splice(screens.findIndex(s=>s.id==='soon-delete'),1);
for(const s of screens){
 if(s.kind==='island'||s.kind==='soon')s.note='Состав и действия сохранены по текущему SwiftUI-экрану. Обновлены оформление, выравнивание и место Пико.';
 if(s.kind==='settings')s.note='Текущие 620×659 pt, сайдбар 200 pt и контент с отступом 20 pt. Сохранены исходные переключатели, ползунки, плитки и действия. Длинная страница прокручивается.';
 if(s.kind==='agent')s.note=`Текущие ${s.width}×${s.height} pt. Сохранены сессии, фильтр ожидающих, данные агента, навигация по запросам и вопросам, свой ответ и отправка.`;
 if(s.id==='overview')s.note='Сохранены три колонки 184 / 280 / 204 pt: музыка, календарь с Claude и Codex, Soon. Пико находится в свободной части блока даты.';
 if(s.id==='duo')s.note='Состав Duo сохранён: обложка, название, артист, три кнопки, дата, карточки событий, место и Join. Полосы времени здесь нет. Пико занимает свободное место над названием.';
 if(s.id==='music-peek'){s.height=51;s.note='Текущие 276×51 pt. Название трека находится под камерой. Пико не вытесняет обложку, волну или текст.';}
 if(s.id==='airpods'){s.width=254;s.height=32;s.note='Текущий компакт: глиф модели и кольцо заряда. Дополнительной подписи в приложении нет.';}
 if(s.id==='low-battery')s.width=373;
 if(s.id==='low-power')s.width=435;
 if(s.id==='queue'){s.height=99.5;s.note='Текущая строка очереди высотой 26 pt под уведомлением 73,5 pt. Нажатие открывает список ожидающих.';}
 if(s.id==='charging')s.note='Текущее уведомление Charging: подпись и батарейка. Процент не показывается.';
 if(s.id==='low-power')s.note='Текущее уведомление Low Power Mode: подпись и батарейка без процента. Ширина 185 + 2×125 pt из BatteryAlertWing.';
}
add('Soon','soon-completed-detail','Soon · завершённая карточка','soon','completed-detail',345,207,'Сохранены время завершённого напоминания, состояние, Повторить и Удалить.');
for(const provider of ['claude','codex']){
 add(provider==='claude'?'Claude Code':'Codex',provider+'-final',(provider==='claude'?'Claude':'Codex')+' · последний вопрос','agent','final',640,320,'Последний вопрос пакета. Доступна отдельная отправка «Ответить ⌘↩».',{provider});
 add(provider==='claude'?'Claude Code':'Codex',provider+'-context',(provider==='claude'?'Claude':'Codex')+' · контекст созвона','agent','question',640,320,'Текущая строка контекста: созвон, Войти, музыка и счётчик Soon. Форма вопроса прокручивается.',{provider,context:true});
}
add('Остров','player-favorite','Плеер · Favorite','island','player',345,207,'Дополнительная кнопка Favorite из текущего PlayerControl. Показывается при поддержке источником.',{extra:'favorite'});
add('Остров','player-repeat','Плеер · Repeat','island','player',345,207,'Дополнительная кнопка Repeat из текущего PlayerControl.',{extra:'repeat'});
add('Настройки','settings-claude-reconnect','Настройки · обновление hooks','settings','claudeCode',620,659,'Текущее состояние сохранённого подключения: Обновить и Отключить.',{connectionState:'reconnect'});
add('Настройки','settings-codex-disconnected','Настройки · подключение Codex','settings','codex',620,659,'Текущее состояние без подключения общего сервера Codex.',{connectionState:'disconnected'});
add('Настройки','settings-soon-denied','Настройки · нет разрешения macOS','settings','soon',620,659,'Текущее предупреждение об отключённых уведомлениях macOS и переход в системные настройки.',{authorization:'denied'});
add('Компакт и уведомления','queue-list','Очередь · список ожидающих','popover','queue-list',300,156,'Текущий popover PeekQueueList. Список содержит названия и детали уведомлений, ожидающих показа.');
add('Компакт и уведомления','queue-capsule','Очередь · отдельная капсула','overlay','queue-capsule',464,73.5,'Остров 400×73,5 pt, капсула 56×28 pt и промежуток 8 pt. Общая ширина превью 464 pt.');

for(const s of screens){if(s.id==='calendar-compact'||s.id==='calendar-peek')s.width=285;if(s.id==='airpods')s.width=269;if(s.id==='agents-compact')s.width=345;}

add('Остров','calendar-all-day','Календарь · событие на весь день','island','calendar',345,207,'Текущее событие на весь день: заголовок без времени. Для дня рождения сохранён специальный значок.',{allDay:true});
