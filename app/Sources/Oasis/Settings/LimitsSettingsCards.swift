import IslandCore
import SwiftUI

/// Общие группы настроек лимитов Claude Code и Codex.
struct LimitsSettingsCards: View {
  @ObservedObject var settings: LimitsSettings
  let preview: (IslandSound) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if settings.enabled {
        SettingsCard(title: "Предупреждения") {
          ToggleRow(
            title: "Предупреждение о лимите сессии", info: "Peek, когда остаток основного окна падает ниже порога",
            isOn: $settings.sessionWarning)
          if settings.sessionWarning {
            RowDivider()
            ThresholdRow(selection: $settings.thresholds)
            RowDivider()
            ToggleRow(title: "Звук на 5% и 0%", preview: { preview(.lowBattery) }, isOn: $settings.criticalSound)
          }
          RowDivider()
          ToggleRow(title: "Сброс окна", info: "Peek, когда лимит снова 100%", isOn: $settings.resetNotice)
        }
        SettingsCard(title: "Раскрытый остров") {
          ToggleRow(title: "Вид в раскрытом острове", isOn: $settings.expandedView)
          if settings.expandedView {
            RowDivider()
            LimitsChoiceRow(
              title: "Прогноз дня до", selection: $settings.forecastUntilWorkday,
              options: [(value: false, title: "Полночь"), (value: true, title: "Конец рабочего дня")])
            if settings.forecastUntilWorkday {
              RowDivider()
              WorkdayEndRow(minutes: $settings.workdayEnd)
            }
          }
        }
      }
    }
  }
}

/// Пороги 50, 25, 10, 5: плитки, можно выбрать несколько
struct ThresholdRow: View {
  @Binding var selection: [Int]
  static let options = [50, 25, 10, 5]

  var body: some View {
    HStack {
      Text("Пороги").font(.system(size: 13))
      Spacer()
      ForEach(Self.options, id: \.self) { value in
        let isOn = selection.contains(value)
        Button {
          toggle(value)
        } label: {
          Text("\(value)%")
            .font(.system(size: 12, weight: .medium))
            .frame(width: 44, height: 24)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isOn ? SettingsPalette.accent : Color.primary.opacity(0.08))
            )
            .foregroundStyle(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, SettingsLayout.rowInset)
    .padding(.vertical, 6)
  }

  private func toggle(_ value: Int) {
    let updated = selection.contains(value) ? selection.filter { $0 != value } : selection + [value]
    selection = updated.sorted(by: >)
  }
}

/// Конец рабочего дня: слайдер 16:00…23:00 с шагом 30 минут, значение — «20:00»
struct WorkdayEndRow: View {
  @Binding var minutes: Int

  var body: some View {
    HStack {
      Text("Конец рабочего дня").font(.system(size: 13))
      Spacer()
      Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }), in: 960...1380, step: 30)
        .frame(width: 160)
        .tint(SettingsPalette.accent)
      Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .frame(width: 44)
    }
    .padding(.horizontal, SettingsLayout.rowInset)
    .padding(.vertical, 6)
  }
}

/// Компактный выбор для двух настроек модуля.
struct LimitsChoiceRow: View {
  let title: String
  @Binding var selection: Bool
  let options: [(value: Bool, title: String)]

  var body: some View {
    HStack {
      Text(title).font(.system(size: 13))
      Spacer()
      Picker(title, selection: $selection) {
        ForEach(options, id: \.value) { option in
          Text(option.title).tag(option.value)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .fixedSize()
    }
    .padding(.horizontal, SettingsLayout.rowInset)
    .padding(.vertical, 8)
  }
}
