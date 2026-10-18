import IslandCore
import SwiftUI

struct ExpandedNavigation: View {
  let view: ExpandedView
  let width: CGFloat
  let notchWidth: CGFloat
  let onSelectView: (ExpandedView) -> Void
  let onOpenSettings: () -> Void
  var waitingCount = 0
  var attentionCount = 0
  var onFilterWaiting: () -> Void = {}

  private var wide: Bool { width >= 560 }
  private var wing: CGFloat { max(0, (width - notchWidth) / 2 - (wide ? 20 : 10)) }

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 4) {
        tab("Обзор", target: .overview)
        if wide { tab("Модули", target: .modules) }
      }
      .frame(width: wing, alignment: .leading)
      Color.clear.frame(width: notchWidth)
      HStack(spacing: 6) {
        Spacer(minLength: 0)
        if view == .agents {
          Button(action: onFilterWaiting) {
            Text("\(waitingCount) ждут ответа").font(.system(size: 10)).foregroundStyle(ClaudeAgentsStyle.accent)
          }.help("Показать ожидающих ответа")
        }
        if !wide {
          Button {
            onSelectView(.modules)
          } label: {
            Image(systemName: "square.grid.2x2")
          }
          .help("Модули")
          .accessibilityLabel("Модули")
        }
        Button {
          onSelectView(.inbox)
        } label: {
          Image(systemName: attentionCount > 0 ? "tray.full" : "tray")
        }.help("Входящие · \(attentionCount)").accessibilityLabel("Входящие")
        Button(action: onOpenSettings) {
          Image(systemName: "gearshape")
        }
        .help("Настройки Oasis")
        .accessibilityLabel("Настройки Oasis")
        .frame(width: 24, height: 24)
      }
      .frame(width: wing, alignment: .trailing)
    }
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(IslandPalette.secondary)
    .buttonStyle(.plain)
    .padding(.horizontal, wide ? 20 : 10)
    .frame(width: width, height: ExpandedLayout.headerHeight)
  }

  private func tab(_ title: String, target: ExpandedView) -> some View {
    Button {
      onSelectView(target)
    } label: {
      Text(title)
        .foregroundStyle(view == target ? IslandPalette.foreground : IslandPalette.secondary)
        .padding(.horizontal, wide ? 10 : 4)
        .frame(height: 24)
        .background {
          if view == target { Capsule().fill(IslandPalette.pressed) }
        }
        .contentShape(Capsule())
    }
    .accessibilityAddTraits(view == target ? .isSelected : [])
  }
}
