import IslandCore
import SwiftUI

struct CodexLimitsView: View {
  let panel: CodexLimitsPanel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "terminal").foregroundStyle(IslandPalette.foreground)
        Text("Codex").font(.system(size: 13, weight: .semibold))
        Spacer(minLength: 8)
        Text(panel.freshness).font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          if let limits = panel.limits {
            ForEach(limits.buckets) { bucket in
              if limits.buckets.count > 1 { Text(bucket.title).font(.system(size: 11, weight: .medium)) }
              HStack(spacing: 10) {
                ForEach(bucket.windows) { window in CodexLimitCard(window: window, now: panel.now) }
              }
            }
          }
          if let forecast = panel.forecastText {
            Text(forecast).font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          if let status = panel.status {
            Text(status).font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
    .foregroundStyle(IslandPalette.foreground)
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .frame(width: DuoLayout.size.width, height: DuoLayout.size.height, alignment: .top)
  }
}

private struct CodexLimitCard: View {
  let window: CodexLimits.Window
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(window.title).font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(window.remaining)%").font(.system(size: 22, weight: .semibold)).monospacedDigit()
        Text("осталось").font(.system(size: 11)).foregroundStyle(IslandPalette.secondary)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(IslandPalette.placeholder)
          Capsule().fill(Color(ActivityLayouts.limitColor(remaining: window.remaining)))
            .frame(width: proxy.size.width * Double(window.remaining) / 100)
        }
      }
      .frame(height: 4)
      Text(resetText).font(.system(size: 10)).foregroundStyle(IslandPalette.secondary)
        .lineLimit(1).minimumScaleFactor(0.8)
    }
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(IslandPalette.placeholder, lineWidth: 1))
  }

  private var resetText: String {
    guard let date = window.resetsAt else { return "Время сброса неизвестно" }
    guard date > now else { return "Сброс ожидается, ждём обновления" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "EEE HH:mm"
    return "Сброс \(formatter.string(from: date))"
  }
}
