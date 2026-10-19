import IslandCore
import SwiftUI

struct PeekQueueOverlay: View {
  let surface: Surface
  let spec: IslandShapeSpec
  let items: [IslandAttention]
  let appearance: PeekQueueAppearance

  var body: some View {
    GeometryReader { proxy in
      let visible = PeekQueueGeometry.isVisible(surface: surface, count: items.count)
      let frame = PeekQueueGeometry.indicatorFrame(content: spec, appearance: appearance, windowWidth: proxy.size.width)
      PeekQueueView(items: items, style: appearance.style)
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }
  }
}

struct PeekQueueView: View {
  let items: [IslandAttention]
  let style: PeekQueueStyle
  @State private var showsList = false

  var body: some View {
    Button {
      showsList.toggle()
    } label: {
      HStack(spacing: style == .row ? 7 : 6) {
        Image(systemName: "square.stack.3d.up")
          .font(.system(size: 14, weight: .medium))
        if style == .row { Text("В очереди") }
        Text("\(items.count)").fontWeight(.semibold).monospacedDigit()
        if style == .row {
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 10)).foregroundStyle(IslandPalette.tertiary)
        }
      }
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(IslandPalette.foreground)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        if style == .capsule { Capsule().fill(.black) }
      }
      .contentShape(.rect)
      .overlay(alignment: .top) {
        if style == .row { Rectangle().fill(IslandPalette.divider).frame(height: 1) }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Открыть очередь, ожидают: \(items.count)")
    .popover(isPresented: $showsList, arrowEdge: .bottom) {
      PeekQueueList(items: items)
        .preferredColorScheme(.dark)
    }
    .onChange(of: items.isEmpty) { _, empty in
      if empty { showsList = false }
    }
  }
}

private struct PeekQueueList: View {
  let items: [IslandAttention]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Ожидают показа · \(items.count)")
        .font(.system(size: 11, weight: .medium)).foregroundStyle(IslandPalette.secondary)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            HStack(alignment: .top, spacing: 10) {
              Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(IslandPalette.secondary).frame(width: 16)
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                Text(item.detail).font(.system(size: 10)).foregroundStyle(IslandPalette.secondary).lineLimit(1)
              }
              Spacer(minLength: 0)
            }
          }
        }
      }
      .frame(height: CGFloat(min(items.count, 5)) * 47)
    }
    .foregroundStyle(IslandPalette.foreground)
    .padding(16)
    .frame(width: 300)
    .background(.black)
  }
}
