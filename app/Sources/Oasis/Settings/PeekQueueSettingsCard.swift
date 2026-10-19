import IslandCore
import SwiftUI

struct PeekQueueSettingsCard: View {
  @ObservedObject var settings: AppSettings

  var body: some View {
    SettingsCard(title: "Очередь пиков") {
      HStack {
        Text("Вид")
        Spacer()
        Picker("Вид", selection: $settings.peekQueueStyle) {
          Text("Строка").tag(PeekQueueStyle.row)
          Text("Капсула").tag(PeekQueueStyle.capsule)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 190)
      }
      .padding(.horizontal, 12)
      .frame(height: 42)
      if settings.peekQueueStyle == .capsule {
        RowDivider()
        HStack {
          Text("Позиция")
          Spacer()
          Picker("Позиция", selection: $settings.peekQueuePosition) {
            Text("Слева").tag(PeekQueuePosition.left)
            Text("Справа").tag(PeekQueuePosition.right)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .frame(width: 190)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
      }
    }
  }
}
