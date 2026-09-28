import AppKit
import SwiftUI

/// Акцент Alcove: тумблер и заливка слайдера (ui-inspection 1.1)
enum SettingsPalette {
    static let accent = Color(red: 233 / 255, green: 98 / 255, blue: 96 / 255)

    /// Подложка карточки: должна быть светлее окна в обеих темах.
    /// .controlBackgroundColor темнее окна в тёмной теме — карточки «проваливались»
    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.227, alpha: 1)
            : NSColor.white
    })
}

/// Цветная squircle-иконка пункта: ~22 pt в сайдбаре, 26 в заголовке страницы
struct SettingsIcon: View {
    let page: SettingsPage
    let side: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
            .fill(page.tint)
            .frame(width: side, height: side)
            .overlay(
                Image(systemName: page.symbol)
                    .font(.system(size: side * 0.55, weight: .semibold))
                    .foregroundStyle(.white))
    }
}

/// Сверху контента: иконка 26×26 и название 19 pt жирным
struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 8) {
            SettingsIcon(page: page, side: 26)
            Text(page.title).font(.system(size: 19, weight: .bold))
        }
    }
}

/// Карточка строк: скруглённая подложка светлее окна, радиус ~10, серый заголовок группы над ней
struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SettingsPalette.cardBackground))
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 12)
    }
}

/// Что пишется в «пилюле» слайдера. У Alcove: «5.0 s», «-2 px», «10%» (ui-inspection 1.2, 1.3).
/// Сдвиг выреза у нас в pt (решение 28.09), поэтому единица — pt
enum SliderFormat: Equatable {
    case decimal(String)
    case integer(String)
    case percent

    func text(_ value: Double) -> String {
        switch self {
        case let .decimal(unit): String(format: "%.1f %@", value, unit)
        case let .integer(unit): "\(Int(value.rounded())) \(unit)"
        case .percent: "\(Int((value * 100).rounded()))%"
        }
    }

    /// Слайдер шагает по step, но Double-арифметика даёт 0.30000000000000004: округляем до шага
    /// и до тысячных, иначе мусор после запятой попадает в UserDefaults и в подпись
    static func snap(_ value: Double, step: Double) -> Double {
        (((value / step).rounded() * step) * 1000).rounded() / 1000
    }
}

extension Binding where Value == Double {
    /// Запись со снапом до шага слайдера (SliderFormat.snap)
    func snapped(to step: Double) -> Binding<Double> {
        Binding(get: { wrappedValue }, set: { wrappedValue = SliderFormat.snap($0, step: step) })
    }
}

/// Строка с тумблером, 42 pt. preview — кнопка ▶ после подписи: у Alcove у Play sound on low battery (ui-inspection 1.1)
struct ToggleRow: View {
    let title: String
    var info: String? = nil
    var preview: (() -> Void)? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let info { InfoButton(text: info) }
            if let preview { SoundPreviewButton(play: preview) }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(SettingsPalette.accent)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }
}

/// Строка со слайдером, 72 pt: подпись и «пилюля» значения, под ними слайдер
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: SliderFormat

    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: SliderFormat) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) {
        self.init(title: title, value: value, range: range, step: step, format: .decimal(unit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(format.text(value))
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            Slider(value: $value.snapped(to: step), in: range, step: step)
                .tint(SettingsPalette.accent)
        }
        .padding(.horizontal, 12)
        .frame(height: 72)
    }

    nonisolated static func format(_ value: Double, unit: String) -> String {
        SliderFormat.decimal(unit).text(value)
    }
}

/// ⓘ 16 pt: поповер по наведению, без клика
struct InfoButton: View {
    let text: String
    @State private var isShown = false

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .onHover { isShown = $0 }
            .popover(isPresented: $isShown, arrowEdge: .bottom) {
                Text(text).padding(12)
            }
    }
}

/// Главный тумблер страницы: иконка страницы акцентным цветом и её название.
/// Выключен — остальные строки страницы прячутся (ui-inspection 1.1, проверено на Battery)
struct MasterToggleRow: View {
    let page: SettingsPage
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: page.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SettingsPalette.accent)
                .frame(width: 18)
            Text(page.title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(SettingsPalette.accent)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }
}

/// ▶ play.circle.fill 13 pt: проиграть звук настройки (ui-inspection 1.1)
struct SoundPreviewButton: View {
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Preview")
    }
}

/// Плитка выбора: чёрная подложка с превью, подпись под ней
struct Tile<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let preview: AnyView
    var isEnabled = true
    var id: Value { value }
}

/// Ряд плиток. Выбранная — красная обводка ~2 pt и жирная подпись (ui-inspection 1.1).
/// Размеры плиток у Alcove 107×40 (3 в ряд), 165×48 (2), 77×40 (4): ширина делится поровну, высота — параметр
struct TileRow<Value: Hashable>: View {
    let tiles: [Tile<Value>]
    @Binding var selection: Value
    var height: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(tiles) { tile in
                let selected = tile.value == selection
                VStack(spacing: 4) {
                    tile.preview
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(selected ? SettingsPalette.accent : .clear, lineWidth: 2))
                    Text(tile.title)
                        .font(.system(size: 11, weight: selected ? .bold : .regular))
                }
                .opacity(tile.isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
                .onTapGesture { if tile.isEnabled { selection = tile.value } }
            }
        }
        .padding(12)
    }
}
