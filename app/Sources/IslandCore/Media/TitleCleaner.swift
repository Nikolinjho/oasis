import Foundation

/// Hide media title extras (ui-inspection 1.8): у браузерных источников в названии «(Official Video)», «[4K]» и т.п.
/// Какие хвосты режет Alcove, не проверяли: список — оценка по названиям YouTube. «feat.» — часть трека, не трогаем
public enum TitleCleaner {
  private static let keywords = "official|video|audio|lyrics?|lyric video|visuali[sz]er|remaster(ed)?|hd|hq|4k|mv|clip"

  /// Скобки, где есть ключевое слово, и хвост после « | » с ним же
  private static let patterns: [NSRegularExpression] = [
    #"\s*[\(\[][^\)\]]*\b(\#(keywords))\b[^\)\]]*[\)\]]"#,
    #"\s*\|\s*[^|]*\b(\#(keywords))\b.*$"#,
    // swiftlint:disable:next force_try - шаблоны — литералы в коде, битую регулярку сразу поймает TitleCleanerTests
  ].map { try! NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

  public static func clean(_ title: String) -> String {
    var result = title
    for pattern in patterns {
      let range = NSRange(result.startIndex..., in: result)
      result = pattern.stringByReplacingMatches(in: result, range: range, withTemplate: "")
    }
    let trimmed = result.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? title : trimmed
  }
}
