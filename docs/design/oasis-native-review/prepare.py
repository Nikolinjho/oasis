"""Создаёт изолированную копию исходников для снимков. Приложение в app/ не меняет."""
from pathlib import Path
import shutil,plistlib
here=Path(__file__).resolve().parent
repo=here.parents[2]
work=Path('/tmp/oasis-native-review')
for module in ['IslandCore','IslandSources','IslandUI','Oasis']:
 shutil.copytree(repo/'app/Sources'/module,work/'Sources'/module,dirs_exist_ok=True)
shutil.copy2(here/'Package.swift.txt',work/'Package.swift')
shutil.copy2(here/'ReviewExporter.swift',work/'Sources/IslandUI/ReviewExporter.swift')
shutil.copy2(here/'main.swift',work/'Sources/Oasis/main.swift')
# Цвета — единственное изменение оформления. Верстка компонентов остаётся исходной.
shutil.copy2(here/'review-palette.swift',work/'Sources/IslandUI/IslandPalette.swift')
p=work/'Sources/Oasis/Settings/SettingsView.swift'
p.write_text(p.read_text().replace('@State private var page: SettingsPage = .general','@State var page: SettingsPage = .general'))
print(work)
