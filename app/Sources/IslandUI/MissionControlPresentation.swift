import AppKit
import ApplicationServices
import Observation
import SwiftUI

/// В обзоре окон отключает внешние эффекты острова, сохраняя форму и управление.
@MainActor
@Observable
final class MissionControlPresentation {
  private(set) var isActive = false
  @ObservationIgnored private var timer: Timer?

  func start() {
    update()
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.update() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    isActive = false
  }

  private func update() {
    let active = Self.isMissionControlActive()
    guard active != isActive else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { isActive = active }
  }

  static func isMissionControlActive() -> Bool {
    guard AXIsProcessTrusted(),
      let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
    else { return false }
    let application = AXUIElementCreateApplication(dock.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.05)
    var children: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, kAXChildrenAttribute as CFString, &children) == .success,
      let elements = children as? [AXUIElement]
    else { return false }
    return elements.contains { element in
      var identifier: CFTypeRef?
      return AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier) == .success
        && identifier as? String == "mc"
    }
  }
}
