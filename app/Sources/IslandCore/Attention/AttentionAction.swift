import Foundation

public enum AttentionAction: Sendable {
  case open(UUID)
  case join(UUID)
  case completeSoon(UUID)
  case snoozeSoon(UUID, seconds: Int)
}
