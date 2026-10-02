import CoreGraphics

public enum MediaKey: Equatable, Sendable {
  case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
}

public struct MediaKeyPress: Equatable, Sendable {
  public var key: MediaKey
  public var isDown: Bool
  public var isRepeat: Bool
  /// Option+Shift: шаг 1/64
  public var fine: Bool

  public init(key: MediaKey, isDown: Bool, isRepeat: Bool, fine: Bool) {
    self.key = key
    self.isDown = isDown
    self.isRepeat = isRepeat
    self.fine = fine
  }

  /// NSSystemDefined подтип 8: код клавиши NX_KEYTYPE_* в старших 16 битах data1, состояние в младших
  public static func decode(subtype: Int, data1: Int, flags: CGEventFlags) -> MediaKeyPress? {
    guard subtype == 8 else { return nil }
    let code = (data1 & 0xFFFF_0000) >> 16
    let state = data1 & 0xFFFF
    let key: MediaKey
    switch code {
    case 0: key = .volumeUp  // NX_KEYTYPE_SOUND_UP
    case 1: key = .volumeDown  // NX_KEYTYPE_SOUND_DOWN
    case 2: key = .brightnessUp  // NX_KEYTYPE_BRIGHTNESS_UP
    case 3: key = .brightnessDown  // NX_KEYTYPE_BRIGHTNESS_DOWN
    case 7: key = .mute  // NX_KEYTYPE_MUTE
    default: return nil
    }
    return MediaKeyPress(
      key: key,
      isDown: (state & 0xFF00) >> 8 == 0x0A,
      isRepeat: state & 0x1 != 0,
      fine: flags.contains(.maskAlternate) && flags.contains(.maskShift))
  }
}
