import Foundation

/// Общая ширина слотов вокруг камеры для формы и содержимого компакта.
public enum ActivityComposition {
  public static func width(notchWidth: CGFloat, calendar: Bool, music: Bool, agentProviders: Int = 1) -> CGFloat {
    let reference: CGFloat
    if calendar && music { reference = 400 } else if calendar { reference = 345 } else if music { reference = 320 } else { reference = 300 }
    return reference + (notchWidth - 185) + (agentProviders > 1 ? 64 : 0)
  }
}
