# T3Notch — разбор как референса

Репозиторий: https://github.com/zortos293/T3Notch (коммит `f334abd`, 12.08.2026). Swift 6.3, SwiftUI + AppKit, macOS 26+. У Ники собирается на Xcode 27 за ~10 с (`swift build`).

> **Лицензии нет** (файла LICENSE нет, в README не указана). По умолчанию это «все права защищены»: код не копировать, паттерны изучать и писать своё.

Это «notch в стиле Alcove» для агентов T3 Code. Примерно 60% кода — клиент T3 Code (DPoP, удалённые машины, агенты), для нас бесполезно. Полезна обвязка острова.

## Что берём как паттерн

| Что | Где | Суть |
|---|---|---|
| Окно фиксированного размера | `NotchGeometry.windowFrame`, `NotchPanel` | Одно прозрачное окно под самое большое состояние. Внутри анимируется только форма, окно не ресайзится, поэтому пружина плавная |
| Клики только по нарисованному | `NotchPanel.syncInteractivity` | `ignoresMouseEvents` переключается на каждое движение мыши: вне формы клики уходят в menu bar и окна под ним |
| Hover через глобальный монитор | `NotchPanelController.updateHover` | `NSEvent.addGlobalMonitorForEvents(.mouseMoved)` вместо tracking area, потому что свёрнутое окно игнорирует мышь. Зона hover — вырез ±30×6 pt |
| Уровень и поведение окна | `NotchPanel.init` | `.borderless + .nonactivatingPanel`, level `statusBar + 1`, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `animationBehavior = .none` |
| Геометрия выреза | `NotchGeometry.physicalNotchRect` | Вырез = промежуток между `auxiliaryTopLeftArea` и `auxiliaryTopRightArea`, высота = `safeAreaInsets.top` |
| Виртуальный вырез | `NotchGeometry.metrics` | Для экранов без выреза: 200×32 по центру. Аналог `forceSimulatedNotch` у Alcove |
| Выбор экрана | `preferredScreen(named:)` | Сохранённое имя → встроенный с вырезом → main. Перестановка по `didChangeScreenParametersNotification` |
| Вогнутые «плечи» | `NotchShape` | Верхние углы вогнутые (wing 14 pt), форма перетекает в menu bar. У Alcove такие же плечи видны на записях. Сделано на quad-кривых, нам нужен squircle |
| Раскладка компакта | `TopStrip` | `Spacer().frame(width: notchWidth)` резервирует вырез, контент по бокам |
| Окно настроек у агента без Dock | `SettingsWindowController.show` | На время открытия `setActivationPolicy(.regular)`, при закрытии обратно. Иначе окно теряется за другими |
| Автозапуск | `LoginItem` | `SMAppService.mainApp` с честным показом ошибки для ad-hoc подписи |
| Сборка без Xcode-проекта | `Package.swift`, `Scripts/bundle.sh` | SwiftPM + скрипт сборки `.app` с Info.plist. Параллельные агенты не конфликтуют в `.pbxproj` |

## Что не берём

- **Анимации.** Одна общая пружина `response 0.34, dampingFraction 0.78` на всё. Нет сжатия при смене активности, нет squircle, нет разницы между раскрытием и схлопыванием. Наши замеры Alcove (`motion/`, `capture/analysis/`) точнее.
- Автообновление через GitHub Releases (`Updater`) — для личной сборки не нужно.
- Всё из `T3NotchCore`.

## Идея на потом

Модуль «агенты под вырезом» (статус Claude Code, ожидает ответа, готово) — ровно то, что делает T3Notch для T3 Code. Хорошо ложится вторым модулем после музыки.
