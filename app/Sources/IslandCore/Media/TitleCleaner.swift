import Foundation

/// Hide media title extras (ui-inspection 1.8): у браузерных источников в названии «(Official Video)», «[4K]» и т.п.
/// Какие хвосты режет Alcove, не проверяли: список — оценка по названиям YouTube. «feat.» — часть трека, не трогаем
public enum TitleCleaner {
  /// Слова служебной метки. Режем метку, только если она целиком из них, модификаторов и года: иначе
  /// «(Live in HD Arena)» или «(Clip Art Remix)» теряли часть названия из-за одного совпавшего слова
  private static let tagWords: Set<String> = [
    "official", "video", "audio", "lyric", "lyrics", "visualizer", "visualiser",
    "remaster", "remastered", "hd", "hq", "4k", "mv", "clip", "videoclip",
    "официальное", "официальный", "официальная", "видео", "клип", "клипа", "видеоклип", "премьера", "аудио",
  ]
  /// Засчитываются только рядом с настоящей меткой: «(Official Live Video)» срезаем, а «(Live)», «(Music)»
  /// или «(Live in HD Arena)» — часть названия
  private static let modifiers: Set<String> = [
    "music", "live", "animated", "performance", "version", "explicit", "in", "4k60", "1080p", "60fps", "full",
  ]

  /// Скобки без вложенных скобок
  private static let bracket = try? NSRegularExpression(pattern: #"\s*[\(\[]([^\(\)\[\]]*)[\)\]]"#)
  /// Последний хвост после « - », « – » или « — » (пробелы вокруг обязательны: «Anti-Hero» не хвост)
  private static let dashTail = try? NSRegularExpression(pattern: #"\s+[\-–—]\s+([^\-–—|]*)$"#)

  public static func clean(_ title: String) -> String {
    var result = title
    var previous = ""
    // хвостов может быть несколько: «Song - Lyrics Video | Official Audio»
    while result != previous {
      previous = result
      result = strip(bracket, from: result, minWords: 1)
      // одно голое слово после дефиса — скорее название: India.Arie – «Video»
      result = strip(dashTail, from: result, minWords: 2)
      result = stripPipeSegment(result)
    }
    let trimmed = result.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? title : trimmed
  }

  /// Вырезает совпадения, чья первая группа — служебная метка; с конца, чтобы не сбить диапазоны
  private static func strip(_ regex: NSRegularExpression?, from text: String, minWords: Int) -> String {
    guard let regex else { return text }
    var result = text
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    for match in matches.reversed() {
      guard let whole = Range(match.range, in: text), let inner = Range(match.range(at: 1), in: text),
        isTag(String(text[inner]), minWords: minWords)
      else { continue }
      result.removeSubrange(whole)
    }
    return result
  }

  /// «Song | Official Video | Artist»: служебный сегмент между « | » режем вместе со всем после него —
  /// дальше на YouTube обычно канал или подпись, не название
  private static func stripPipeSegment(_ text: String) -> String {
    let parts = text.components(separatedBy: "|")
    guard let index = parts.indices.dropFirst().first(where: { isTag(parts[$0], minWords: 1) }) else { return text }
    return parts[..<index].joined(separator: "|").trimmingCharacters(in: .whitespaces)
  }

  private static func isTag(_ text: String, minWords: Int) -> Bool {
    let words = text.lowercased()
      .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "/,&+-–—")))
      .filter { !$0.isEmpty }
    let isYear = { (word: String) in word.count == 4 && word.allSatisfy(\.isNumber) }
    guard words.count >= minWords,
      words.allSatisfy({ tagWords.contains($0) || modifiers.contains($0) || isYear($0) })
    else { return false }
    return words.contains { tagWords.contains($0) && !modifiers.contains($0) }
  }
}
