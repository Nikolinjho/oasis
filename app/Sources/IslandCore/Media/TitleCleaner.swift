import Foundation

/// Hide media title extras (ui-inspection 1.8): у браузерных источников в названии «(Official Video)», «[4K]» и т.п.
/// Какие хвосты режет Alcove, не проверяли: список — оценка по названиям YouTube. «feat.» — часть трека, не трогаем
public enum TitleCleaner {
  /// Слова служебной метки. Режем метку, только если она целиком из них (плюс год): иначе
  /// «(Live in HD Arena)» или «(Clip Art Remix)» теряли часть названия из-за одного совпавшего слова
  private static let tagWords: Set<String> = [
    "official", "music", "video", "audio", "lyric", "lyrics", "visualizer", "visualiser",
    "remaster", "remastered", "hd", "hq", "4k", "mv", "clip", "videoclip",
    "официальное", "официальный", "официальная", "видео", "клип", "клипа", "видеоклип", "премьера", "аудио",
  ]
  /// Сами по себе не метка: «(Music)» или «(1999)» — скорее часть названия
  private static let modifierOnly: Set<String> = ["music"]

  /// Скобки без вложенных скобок
  private static let bracket = try? NSRegularExpression(pattern: #"\s*[\(\[]([^\(\)\[\]]*)[\)\]]"#)
  /// Последний хвост после « | », « - », « – » или « — » (пробелы вокруг обязательны: «Anti-Hero» не хвост)
  private static let tail = try? NSRegularExpression(pattern: #"\s+[|\-–—]\s+([^|\-–—]*)$"#)

  public static func clean(_ title: String) -> String {
    var result = title
    var previous = ""
    // хвостов может быть несколько: «Song - Lyrics | Official Audio»
    while result != previous {
      previous = result
      result = strip(bracket, from: result)
      result = strip(tail, from: result)
    }
    let trimmed = result.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? title : trimmed
  }

  /// Вырезает совпадения, чья первая группа — служебная метка; с конца, чтобы не сбить диапазоны
  private static func strip(_ regex: NSRegularExpression?, from text: String) -> String {
    guard let regex else { return text }
    var result = text
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches.reversed() {
      guard let whole = Range(match.range, in: text), let inner = Range(match.range(at: 1), in: text),
        isTag(String(text[inner]))
      else { continue }
      result.removeSubrange(whole)
    }
    return result
  }

  static func isTag(_ text: String) -> Bool {
    let words = text.lowercased()
      .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "/,&+")))
      .filter { !$0.isEmpty }
    let isYear = { (word: String) in word.count == 4 && word.allSatisfy(\.isNumber) }
    guard words.allSatisfy({ tagWords.contains($0) || isYear($0) }) else { return false }
    return words.contains { !isYear($0) && !modifierOnly.contains($0) }
  }
}
