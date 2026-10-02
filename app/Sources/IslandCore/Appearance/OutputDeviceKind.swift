/// Куда сейчас идёт звук: глиф для Show device в HUD громкости и для кнопки вывода в плеере.
/// У Alcove на AirPods в HUD наушники, на плитке настроек — глиф AirPods (ui-inspection 1.7): берём модель
public enum OutputDeviceKind: Equatable, Sendable {
  case speakers
  case headphones
  case airpods(AirPodsInfo.Model?)
  case display
  case other

  public var symbol: String {
    switch self {
    case .speakers: "laptopcomputer"
    case .headphones: "headphones"
    case .airpods(let model): AirPodsInfo(name: "", battery: nil, model: model).symbol
    case .display: "display"
    case .other: "speaker.wave.2.fill"
    }
  }
}
