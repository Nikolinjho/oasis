import Observation
import SwiftUI

@MainActor
@Observable
final class BackSwipePresentation {
  private(set) var offset: CGFloat = 0
  var navigating = false

  func reset() {
    offset = 0
    navigating = false
  }

  func drag(progress: CGFloat) {
    guard !navigating else { return }
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) { offset = min(max(progress, 0), 1) * 64 }
  }

  func settle(timeScale: Double) {
    withAnimation(.smooth(duration: 0.25 * timeScale)) { offset = 0 }
  }
}
