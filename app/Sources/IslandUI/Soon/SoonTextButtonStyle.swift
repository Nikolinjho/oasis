import SwiftUI

struct SoonTextButtonStyle: ButtonStyle {
  var tint: Color = SoonPalette.accent

  func makeBody(configuration: Configuration) -> some View {
    SoonTextButtonLabel(configuration: configuration, tint: tint)
  }
}

private struct SoonTextButtonLabel: View {
  let configuration: ButtonStyleConfiguration
  let tint: Color
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    configuration.label
      .fontWeight(.semibold)
      .underline(true, color: tint.opacity(isHovered ? 1 : 0.6))
      .foregroundStyle(isHovered ? SoonPalette.foreground : tint)
      .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.4)
      .contentShape(Rectangle())
      .onHover { isHovered = $0 }
  }
}
