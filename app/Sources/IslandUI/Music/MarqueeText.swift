import IslandCore
import SwiftUI

/// Бегущая строка 30 pt/с с гаснущими краями (motion.md, «Бегущая строка в peek»). Короткий текст стоит по центру
struct MarqueeText: View {
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var start = Date()
    // замера нет, оценка
    private let gap: CGFloat = 32
    /// Начало полностью видимой полосы маски: с него стартует длинный текст
    private let visibleStart: CGFloat = 0.11

    var body: some View {
        GeometryReader { proxy in
            let overflow = textWidth > proxy.size.width
            TimelineView(.animation(paused: !overflow)) { context in
                let cycle = textWidth + gap
                let travelled = CGFloat(context.date.timeIntervalSince(start)) * IslandTiming.marqueeSpeed
                HStack(spacing: gap) {
                    label
                    if overflow { label }
                }
                .offset(x: overflow ? proxy.size.width * visibleStart - travelled.truncatingRemainder(dividingBy: cycle) : 0)
                .frame(width: proxy.size.width, alignment: overflow ? .leading : .center)
            }
            .mask(overflow ? AnyView(fadeMask) : AnyView(Color.black))
        }
        .clipped()
        // новый текст бежит с начала
        .onChange(of: text) { start = .now }
    }

    private var label: some View {
        Text(text)
            .lineLimit(1)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
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
