/// Яркость фона под раскрытым островом для Contrast outline. Alcove берёт её из CABackdropLayer
/// (backdropLayer:didChangeLuma:), мы — из снимка полос экрана вокруг формы (ui-inspection §1.2, 03.10)
public enum BackdropLuminance {
  /// Порог «тёмного» фона: решение агента 03.10, у Alcove luminanceThreshold не прочитан
  public static let threshold = 0.35

  /// Средняя относительная яркость 0…1 по пикселям RGBA (по 4 байта, альфа не учитывается).
  /// Веса Rec. 709 по компонентам sRGB без линеаризации: для порога «тёмный / светлый» хватает
  public static func mean(rgba: [UInt8]) -> Double {
    let count = rgba.count / 4
    guard count > 0 else { return 0 }
    var sum = 0.0
    for index in 0..<count {
      let base = index * 4
      sum += 0.2126 * Double(rgba[base]) + 0.7152 * Double(rgba[base + 1]) + 0.0722 * Double(rgba[base + 2])
    }
    return sum / Double(count) / 255
  }

  /// Пустой снимок — тёмный: кант лучше показать лишний раз, на светлом поверх тени его почти не видно
  public static func isDark(rgba: [UInt8], threshold: Double = threshold) -> Bool {
    mean(rgba: rgba) < threshold
  }
}
