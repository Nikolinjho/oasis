import SwiftUI

struct BackSwipeDrag: ViewModifier {
  let offset: CGFloat

  private var progress: CGFloat { min(max(offset / 64, 0), 1) }

  func body(content: Content) -> some View {
    content
      .offset(x: offset)
      .blur(radius: progress * 12)
      .opacity(1 - progress * 0.8)
  }
}

private struct BackSwipeFade: AnimatableModifier {
  var progress: CGFloat
  let distance: CGFloat

  nonisolated var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    // Содержимое исчезает в первой трети хода, прежде чем станет заметен край обрезки.
    let fade = min(max(progress * 3, 0), 1)
    content
      .offset(x: progress * distance)
      .blur(radius: fade * 14)
      .opacity(1 - fade)
  }
}

extension AnyTransition {
  static func swipeBack(timeScale: Double) -> AnyTransition {
    .asymmetric(
      insertion: .modifier(active: BackSwipeFade(progress: 1, distance: -80), identity: BackSwipeFade(progress: 0, distance: -80)),
      removal: .modifier(active: BackSwipeFade(progress: 1, distance: 180), identity: BackSwipeFade(progress: 0, distance: 180))
    )
    .animation(.smooth(duration: 0.25 * timeScale))
  }
}
