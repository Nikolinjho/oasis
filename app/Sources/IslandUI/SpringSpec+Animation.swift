import IslandCore
import SwiftUI

extension SpringSpec {
    /// Физика та же, что у interpolatingSpring, поэтому замеры переносятся без пересчёта
    public var animation: Animation {
        .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping)
    }
}
