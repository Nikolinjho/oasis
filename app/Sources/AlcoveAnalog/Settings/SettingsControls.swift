import SwiftUI

/// Акцент Alcove: тумблер и заливка слайдера (ui-inspection 1.1)
enum SettingsPalette {
    static let accent = Color(red: 233 / 255, green: 98 / 255, blue: 96 / 255)
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
                        .fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 12)
    }
}

/// Строка с тумблером, 42 pt
struct ToggleRow: View {
    let title: String
    var info: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let info { InfoButton(text: info) }
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
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(Self.format(value, unit: unit))
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            Slider(value: $value, in: range, step: step)
                .tint(SettingsPalette.accent)
        }
        .padding(.horizontal, 12)
        .frame(height: 72)
    }

    nonisolated static func format(_ value: Double, unit: String) -> String {
        String(format: "%.1f %@", value, unit)
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
