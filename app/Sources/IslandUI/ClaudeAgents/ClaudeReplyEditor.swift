import AppKit
import IslandCore
import SwiftUI

/// Нативный редактор сохраняет UTF-16 выделение и прокрутку между вопросами и HUD.
struct ClaudeReplyEditor: NSViewRepresentable {
  let text: String
  let position: ClaudeTextPosition
  let editable: Bool
  let onText: (String) -> Void
  let onPosition: (ClaudeTextPosition) -> Void
  let onFocus: () -> Void
  let onSubmit: () -> Void
  let onEscape: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.scrollerStyle = .overlay
    let input = ClaudeInputTextView()
    input.isRichText = false
    input.isAutomaticQuoteSubstitutionEnabled = false
    input.isAutomaticDashSubstitutionEnabled = false
    input.isAutomaticTextReplacementEnabled = false
    input.isVerticallyResizable = true
    input.isHorizontallyResizable = false
    input.autoresizingMask = [.width]
    input.minSize = .zero
    input.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    input.textContainer?.widthTracksTextView = true
    input.textContainerInset = NSSize(width: 3, height: 3)
    input.drawsBackground = false
    input.font = .systemFont(ofSize: 12)
    input.textColor = NSColor(red: 1, green: 250 / 255, blue: 244 / 255, alpha: 1)
    input.insertionPointColor = NSColor(red: 217 / 255, green: 119 / 255, blue: 87 / 255, alpha: 1)
    input.setAccessibilityLabel("Свой ответ Claude")
    input.delegate = context.coordinator
    input.onFocus = onFocus
    input.onSubmit = onSubmit
    input.onEscape = onEscape
    scroll.documentView = input
    context.coordinator.observe(scroll)
    updateNSView(scroll, context: context)
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    guard let input = scroll.documentView as? ClaudeInputTextView else { return }
    let coordinator = context.coordinator
    coordinator.parent = self
    coordinator.applying = true
    defer { coordinator.applying = false }
    input.isEditable = editable
    input.isSelectable = true
    input.onFocus = onFocus
    input.onSubmit = onSubmit
    input.onEscape = onEscape
    if input.string != text { input.string = text }
    if !coordinator.restored || input.window?.firstResponder !== input {
      let count = (text as NSString).length
      let location = min(max(position.location, 0), count)
      let length = min(max(position.length, 0), count - location)
      input.setSelectedRange(NSRange(location: location, length: length))
      if let container = input.textContainer { input.layoutManager?.ensureLayout(for: container) }
      scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, position.scrollY)))
      scroll.reflectScrolledClipView(scroll.contentView)
      coordinator.restored = true
    }
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ClaudeReplyEditor
    var applying = false
    var restored = false
    private var observer: NSObjectProtocol?

    init(_ parent: ClaudeReplyEditor) { self.parent = parent }
    isolated deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func observe(_ scroll: NSScrollView) {
      scroll.contentView.postsBoundsChangedNotifications = true
      observer = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: scroll.contentView, queue: .main
      ) { [weak self, weak scroll] _ in
        MainActor.assumeIsolated {
          guard let self, !self.applying, let input = scroll?.documentView as? NSTextView else { return }
          self.capture(input)
        }
      }
    }

    func textDidChange(_ notification: Notification) {
      guard !applying, let input = notification.object as? NSTextView else { return }
      capture(input)
      parent.onText(input.string)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard !applying, let input = notification.object as? NSTextView else { return }
      capture(input)
    }

    private func capture(_ input: NSTextView) {
      let range = input.selectedRange()
      let next = ClaudeTextPosition(
        location: range.location, length: range.length,
        scrollY: Double(input.enclosingScrollView?.contentView.bounds.origin.y ?? 0))
      if next != parent.position { parent.onPosition(next) }
    }
  }
}

private final class ClaudeInputTextView: NSTextView {
  var onFocus: () -> Void = {}
  var onSubmit: () -> Void = {}
  var onEscape: () -> Void = {}

  override func mouseDown(with event: NSEvent) {
    if isEditable { onFocus() }
    super.mouseDown(with: event)
  }

  override func insertTab(_ sender: Any?) {
    window?.selectNextKeyView(sender)
  }

  override func insertBacktab(_ sender: Any?) {
    window?.selectPreviousKeyView(sender)
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      onEscape()
      return
    }
    if event.keyCode == 36 || event.keyCode == 76, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
      if isEditable { onSubmit() }
      return
    }
    super.keyDown(with: event)
  }
}
