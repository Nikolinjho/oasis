import AppKit
import SwiftUI

struct AgentSecretEditor: NSViewRepresentable {
  let text: String
  let editable: Bool
  let onText: (String) -> Void
  let onFocus: () -> Void
  let onSubmit: () -> Void
  let onEscape: () -> Void

  func makeNSView(context: Context) -> SecretField {
    let field = SecretField()
    field.delegate = context.coordinator
    field.isBordered = false
    field.drawsBackground = false
    field.font = .systemFont(ofSize: 12)
    field.focus = onFocus
    field.submit = onSubmit
    field.escape = onEscape
    return field
  }

  func updateNSView(_ field: SecretField, context: Context) {
    context.coordinator.onText = onText
    field.isEditable = editable
    field.focus = onFocus
    field.submit = onSubmit
    field.escape = onEscape
    if field.stringValue != text { field.stringValue = text }
  }

  func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    var onText: (String) -> Void
    init(onText: @escaping (String) -> Void) { self.onText = onText }
    func controlTextDidChange(_ notification: Notification) {
      if let field = notification.object as? NSSecureTextField { onText(field.stringValue) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
      guard let field = control as? SecretField else { return false }
      if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
        field.escape()
        return true
      }
      if commandSelector == #selector(NSResponder.insertNewline(_:)), NSApp.currentEvent?.modifierFlags.contains(.command) == true {
        field.submit()
        return true
      }
      return false
    }
  }
}

final class SecretField: NSSecureTextField {
  var focus: () -> Void = {}
  var submit: () -> Void = {}
  var escape: () -> Void = {}

  override func mouseDown(with event: NSEvent) {
    if isEditable { focus() }
    super.mouseDown(with: event)
  }
}
