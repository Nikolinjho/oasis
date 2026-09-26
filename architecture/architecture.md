# Как устроен Alcove 1.7.7

Разобрано по бандлу `/Applications/Alcove.app`: Info.plist, entitlements, слинкованные фреймворки, имена Swift-классов и строки из бинарника. Сырые данные лежат рядом:

| Файл | Что внутри |
|---|---|
| `Info.plist` | usage-описания разрешений, URL-схема `alcove://`, `LSUIElement` |
| `entitlements.plist` | права: без sandbox, WeatherKit, Apple Events к конкретным приложениям |
| `frameworks.txt` | 62 библиотеки, из них 2 приватных |
| `classes.txt` | 54 Swift-класса — карта модулей |
| `source-files.txt` | 22 имени исходников, попавших в бинарник через assert и logging |
| `helper-Info.txt`, `helper-api.txt` | XPC-helper для MediaRemote и его протокол |
| `ui-strings.md` | все 264 UI-строки: полная карта настроек и состояний |

## Общая схема

- Агент без иконки в Dock (`LSUIElement = true`), живёт в menu bar (`TrayIcon`).
- **Без sandbox.** Иначе не работали бы Apple Events, приватные фреймворки и глобальный перехват клавиш. Значит, приложение распространяется не через Mac App Store, а напрямую, как DMG.
- SwiftUI внутри AppKit-окон: `NotchPanel` и `NotchBackdropPanel` — два `NSPanel`, контент через `NSHostingView` (`NSHostingViewSuppressingSafeArea.swift` — хак, чтобы SwiftUI не добавлял safe area под вырез).
- Архитектура — набор менеджеров-источников данных и координатор, который решает, что показывать в острове:

```
Источники                          Координация            Окна
MediaManager ─┐                                           NotchPanel (остров)
BatteryManager├─┐                                         NotchBackdropPanel (подложка, блюр)
CalendarManager ┤                                         LockPanel (поверх экрана блокировки)
WeatherManager ─┤    NotchCoordinator ─► NotchController   SettingsWindow
ConnectivityMgr ┼──►  (приоритеты,        (состояние,
FocusManager ───┤     очередь)            анимации)
LockManager ────┤
VolumeManager ──┤
BrightnessMgr ──┤
GameManager ────┤  ◄── NotchSwipeMonitor, MediaKeyManager (ввод)
SpaceManager ───┘
```

## Модули и чем они сделаны

| Модуль | Классы | API |
|---|---|---|
| Now Playing | `MediaManager`, `MusicController`, `BrowserController`, `NSWaveformView`, `ArtworkCutoutLayer` | private **MediaRemote** через XPC-helper, AppleScript к Spotify и Music, `ScriptingBridge` для браузеров, AudioCapture для живой волны |
| HUD громкости | `VolumeManager`, `MediaKeyManager`, `SoundManager` | CoreAudio, перехват медиаклавиш через IOHID и CGEventTap (нужен Accessibility) |
| HUD яркости | `BrightnessManager` | private **DisplayServices**, интеграция с OSD BetterDisplay (`com.betterdisplay.BetterDisplay.osd`) |
| Батарея | `BatteryManager`, `BatteryHelper` | IOKit power sources, уведомления о Low Power Mode |
| AirPods и Bluetooth | `BluetoothController`, `ConnectivityManager` | CoreBluetooth, IOBluetooth; видео моделей в `Resources/*.mp4` |
| Календарь | `CalendarManager`, `CalendarController` | EventKit, «пора выходить» через MapKit (`timeToLeave`, транспорт: пешком, транспорт, авто) |
| Погода | `WeatherManager` | **WeatherKit** (нужен платный Apple Developer), CoreLocation |
| Focus | `FocusManager` | распознаёт режимы по id `com.apple.focus.*` и `com.apple.donotdisturb.mode.*` |
| Экран блокировки | `LockManager`, `LockController`, `LockPanel`, `LoginWindowContainerView` | distributed notifications `com.apple.screenIsLocked/Unlocked`, `screenLockUIIsShown`, `screensaver.didstart`; окно поверх экрана блокировки |
| Игры и полноэкранный режим | `GameManager`, `SpaceManager`, `MissionControlManager` | прячет остров в играх, в полноэкранном режиме, в Mission Control |
| Жесты | `NotchSwipeMonitor`, `HapticFeedback` | свайпы по трекпаду над вырезом, отклик через `NSHapticFeedbackManager` |
| Визуал | `VariableBlurEngine`, `MaterialLuminanceAggregator`, `MaterialBackdropLumaView`, `NSMarqueeTextView` | private `CAFilter` типа `variableBlur` для прогрессивного блюра; анализ яркости под окном для адаптивного контраста |
| Обновления и лицензия | `UpdateManager`, `LicenseManager`, `LicenseController` | свой сервер: `/license/validate`, `/license/issue-token`, `/license/deactivate`; ключ в Keychain |

## Приватные API и обходы

1. **MediaRemote через helper с чужим bundle id.** С macOS 15.4 системный «сейчас играет» отдаётся только процессам Apple. Alcove кладёт в бандл `XPCServices/AlcoveHelper.xpc` с bundle id **`com.apple.controlcenter.AlcoveHelper`**. Helper линкует MediaRemote и по XPC отдаёт `getNowPlayingInfo`, `getNowPlayingBundle`, `startNowPlayingObservation` и команды. Судя по всему, `mediaremoted` проверяет только префикс id. Открытая альтернатива — [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) через системный perl.
2. **`variableBlur`** — приватный фильтр Core Animation (`CAFilter(type: "variableBlur")` с `inputMaskImage` и `inputRadius`). Даёт блюр с плавным нарастанием, публичного аналога нет.
3. **DisplayServices** — чтение и установка яркости встроенного дисплея.
4. **Окно на экране блокировки** (`LoginWindowContainerView`). Обычный `NSWindow` туда не попадает, нужны закрытые механизмы SkyLight. Самое хрупкое место.

Всё это может сломаться с любым апдейтом macOS.

## Разрешения, которые просит

Accessibility, Apple Events (Spotify, Music, Safari, Chrome, Dia), Audio Capture (живая волна), Bluetooth, Calendar (full access), Location, Local Network (проверка лицензии). Без Accessibility не работают жесты и замена HUD.

## Ресурсы

- **Звуки** (`assets/sounds`): lock, unlock, volume, haptic, low-battery, low-power, sleep, chime, event, directions, blips, pad, alt-jingle.
- **Видео AirPods** (`assets/videos`): 15 роликов 96×96 при 60 fps по 6 с, по одному на модель и цвет AirPods Max.
- **Иконки** (`assets/images`): приложения-источники (Spotify, Music, Safari, Chrome, Dia, Calendar, Fantastical, Notion Calendar, FaceTime, Meet) в 18×18 и 52×52, глифы `lock`, `link`, `repeat`, `swipe`.

## Настройки: что стоит повторить

Полный список в `ui-strings.md`, раздел `settings` (141 ключ). Самое показательное:

- **Тюнинг под железо:** `notchWidth`, `notchHeight`, `forceSimulatedNotch` для мониторов без выреза, выбор дисплея (встроенный, основной, все, конкретный).
- **Поведение:** `expandOnHover` + `hoverDuration`, `haptics`, `progressiveBlur`, `contrastOutline`.
- **Скрытие:** в полноэкранном режиме, в Mission Control, в играх, из записи экрана.
- **Жесты:** свайп закрыть, переключить трек, переключиться между активностями, `naturalMovement`.
- **Idle activity:** что показывать в покое — последнее событие, музыка, календарь, `duo` (два виджета сразу).
- **HUD:** скорость (instant, fast, smooth), длительность, стиль прогресса (white, accent, stylized, glow), проценты.
- **Now Playing:** цвет волны (mono, color, gradient, artwork), контролы (shuffle, repeat, like, favorite, copy), отключение переворота обложки.
- **Экран блокировки:** стиль плеера (frosted, glass, clear), погода (sun, conditions, precipitation), звуки блокировки и разблокировки, `keepAwake`.
- **Календарь:** уведомление перед событием и «пора выходить» с запасом времени и видом транспорта, ежечасный бой часов, цвета календарей.
