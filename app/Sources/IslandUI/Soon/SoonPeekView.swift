import IslandCore
import SwiftUI

struct SoonPeekView: View {
  let notice: SoonNotice
  let notchWidth: CGFloat

  private var layout: ActivityLayout { ActivityLayouts.soon(notice) }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ActivityIcon(layout: layout)
          .frame(width: ActivityLayout.iconWidth, height: 15)
        Spacer(minLength: notchWidth)
        Text("Soon")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(SoonPalette.foreground)
          .lineLimit(1)
          .fixedSize()
      }
      .padding(.horizontal, 24)
      .frame(height: 32)
      Text(layout.line?.title ?? notice.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SoonPalette.foreground)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .frame(height: 41.5)
        .accessibilityLabel(notice.title)
    }
    .help(notice.title)
  }
}
