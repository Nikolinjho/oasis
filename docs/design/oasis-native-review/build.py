from pathlib import Path
import base64,json
root=Path(__file__).resolve().parent
screens=json.loads((root/'current/index.json').read_text())
other=json.loads((root/'refreshed/index.json').read_text())
assert [(x['id'],x['width'],x['height']) for x in screens]==[(x['id'],x['width'],x['height']) for x in other]
names={'duo':'Duo','player':'Плеер','calendar':'Календарь','claude':'Лимиты Claude','soon':'Soon','agents':'Сессии Claude','codexAgents':'Сессии Codex','overview':'Обзор','modules':'Модули','inbox':'Входящие'}
for s in screens:
 for key,label in names.items():
  if s['id']==key:s['title']=label
  if s['id']==key+'-empty':s['title']=label+' · пусто'
 s['width']=int(s['width']);s['height']=int(s['height'])
 for folder,key in [('current','before'),('refreshed','after')]:s[key]='data:image/png;base64,'+base64.b64encode((root/folder/(s['id']+'.png')).read_bytes()).decode()
# Prefer main screens first, followed by specialized states and settings.
order=['duo','player','player-volume','calendar','overview','modules','agents','codexAgents','inbox','soon','soon-detail','soon-compose','hover']
screens.sort(key=lambda s:(order.index(s['id']) if s['id'] in order else len(order), s['id']))
page=(root/'template.html').read_text().replace('/* SCREENS */',json.dumps(screens,ensure_ascii=False)).replace('/* PICO */',(root.parent/'oasis-approval/pico.js').read_text()).replace('data-action="emerge"','data-action="call"')
output=root.parent/'oasis-native-comparison-v6.html';output.write_text(page)
print(f'Built {output.name}: {len(screens)} paired native states, {output.stat().st_size:,} bytes')
