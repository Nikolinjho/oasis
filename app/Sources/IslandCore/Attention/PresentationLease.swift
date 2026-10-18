import Foundation

public struct PresentationLease: Equatable, Sendable {
  public enum Owner: Hashable, Sendable {
    case agents(ClaudeRequestID?)
    case soonComposer
    case expanded(ExpandedView)
  }

  public let owner: Owner
  public let generation: UUID

  public init(owner: Owner, generation: UUID = UUID()) {
    self.owner = owner
    self.generation = generation
  }
}
