import IslandCore
import SwiftUI

/// Бегущая строка 34 pt/с с гаснущими краями (motion.md, «Бегущая строка в peek»).
/// Короткий текст стоит на месте: в peek по центру, в плеере у левого края
struct MarqueeText: View {
  let text: String
  var shortAlignment: Alignment = .center
  /// Вынести левое затухание за край вью, чтобы длинный текст начинался вровень с соседними строками
  var outdentsFade = false
  @State private var textWidth: CGFloat = 0
  @State private var start = Date()
  // замера нет, оценка
  private let gap: CGFloat = 32
  /// Начало полностью видимой полосы маски: с него стартует длинный текст
  private let visibleStart: CGFloat = 0.11

  var body: some View {
    GeometryReader { proxy in
      let overflow = textWidth > proxy.size.width
      // полоса шире на вынос: левое затухание уходит за край, текст стартует вровень с соседними строками
      let bleed = overflow && outdentsFade ? proxy.size.width * visibleStart / (1 - visibleStart) : 0
      let width = proxy.size.width + bleed
      TimelineView(.animation(paused: !overflow)) { context in
        let cycle = textWidth + gap
        let travelled = Self.travelled(elapsed: context.date.timeIntervalSince(start))
        HStack(spacing: gap) {
          label
          if overflow { label }
        }
        .offset(x: overflow ? width * visibleStart - travelled.truncatingRemainder(dividingBy: cycle) : 0)
        .frame(width: width, alignment: overflow ? .leading : shortAlignment)
      }
      .frame(width: width, height: proxy.size.height)
      .mask(overflow ? AnyView(fadeMask) : AnyView(Color.black))
      .clipped()
      .offset(x: -bleed)
    }
    // новый текст бежит с начала
    .onChange(of: text) { start = .now }
  }

  /// Сколько строка прошла: стоит marqueeDelay, дальше marqueeSpeed
  nonisolated static func travelled(elapsed: TimeInterval) -> CGFloat {
    CGFloat(max(0, elapsed - IslandTiming.marqueeDelay)) * IslandTiming.marqueeSpeed
  }

  private var label: some View {
    Text(text)
      .lineLimit(1)
      .fixedSize()
      .onGeometryChange(for: CGFloat.self) {
        $0.size.width
      } action: {
        textWidth = $0
      }
  }

  /// Прозрачно до 7%, полностью видно с 11% по 89%, снова прозрачно с 93%
  private var fadeMask: some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0), .init(color: .clear, location: 0.07),
        .init(color: .black, location: 0.11), .init(color: .black, location: 0.89),
        .init(color: .clear, location: 0.93), .init(color: .clear, location: 1),
      ],
      startPoint: .leading, endPoint: .trailing)
  }
}
