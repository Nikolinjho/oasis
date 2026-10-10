import SwiftUI

struct SoonTextButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    SoonTextButtonLabel(configuration: configuration)
  }
}

private struct SoonTextButtonLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    configuration.label
      .fontWeight(.semibold)
      .underline(true, color: SoonStyle.teal.opacity(isHovered ? 1 : 0.6))
      .foregroundStyle(isHovered ? IslandPalette.foreground : SoonStyle.teal)
      .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.4)
      .contentShape(Rectangle())
      .onHover { isHovered = $0 }
  }
}
