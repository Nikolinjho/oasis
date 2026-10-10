import IslandCore
import SwiftUI

public struct SoonComposerView: View {
  @Binding var title: String
  @Binding var duration: String
  let heading: String
  let error: String?
  let submitting: Bool
  let onSubmit: () -> Void
  let onClose: () -> Void
  @FocusState private var focused: Field?
  private enum Field: Hashable { case title, duration }
  private let accent = Color(red: 45 / 255, green: 212 / 255, blue: 191 / 255)

  public init(
    title: Binding<String>, duration: Binding<String>, heading: String = "Новое напоминание",
    error: String? = nil, submitting: Bool = false, onSubmit: @escaping () -> Void, onClose: @escaping () -> Void
  ) {
    _title = title
    _duration = duration
    self.heading = heading
    self.error = error
    self.submitting = submitting
    self.onSubmit = onSubmit
    self.onClose = onClose
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(heading).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        Spacer(minLength: 6)
        Button("Закрыть", action: onClose)
      }
      .frame(height: 16)
      .padding(.top, 34)
      TextField("Что напомнить?", text: $title)
        .textFieldStyle(.plain)
        .focused($focused, equals: .title)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(IslandPalette.pressed, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Что напомнить?")
        .onSubmit { focused = .duration }
        .padding(.top, 8)
      TextField("Через: 17 мин", text: $duration)
        .textFieldStyle(.plain)
        .focused($focused, equals: .duration)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(IslandPalette.pressed, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Через сколько напомнить")
        .onSubmit(onSubmit)
        .padding(.top, 6)
      HStack(spacing: 18) {
        ForEach(["5 мин", "15 мин", "30 мин", "1 час"], id: \.self) { preset in
          Button(preset) {
            duration = preset
            focused = .duration
          }
        }
      }
      .frame(height: 16)
      .padding(.top, 6)
      HStack(spacing: 6) {
        Text(error ?? deadlineText)
          .foregroundStyle(error == nil ? IslandPalette.secondary : IslandPalette.lowBattery)
          .font(.system(size: 10))
          .lineLimit(1)
          .help(error ?? deadlineText)
          .accessibilityLabel(error ?? deadlineText)
        Spacer(minLength: 0)
        Button(submitting ? "Сохраняю…" : "Напомнить", action: onSubmit)
          .disabled(submitting)
      }
      .frame(height: 16)
      .padding(.top, 1)
      Spacer(minLength: 22)
    }
    .padding(.horizontal, 24)
    .frame(width: 345, height: 175, alignment: .top)
    .foregroundStyle(IslandPalette.foreground)
    .font(.system(size: 11))
    .buttonStyle(SoonTextButtonStyle())
    .environment(\.colorScheme, .dark)
    .tint(accent)
    .onAppear { focused = .title }
    .onExitCommand(perform: onClose)
  }

  private var deadlineText: String {
    guard let seconds = try? SoonDurationParser.parse(duration) else { return "От 10 секунд до 24 часов" }
    let date = Date().addingTimeInterval(Double(seconds))
    return "В " + date.formatted(date: .omitted, time: .standard)
  }
}
