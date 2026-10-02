import IslandCore
import SwiftUI

extension SpringSpec {
  /// Та же пружина с массой 1, что в замерах, поэтому они переносятся без пересчёта.
  /// .spring(Spring) вместо interpolatingSpring: при прерывании (быстрый hover туда и обратно)
  /// она перенацеливается с сохранением скорости, а interpolatingSpring складывает скорости двух анимаций.
  /// allowOverDamping: у части замеров ζ чуть больше 1 (185/27.5), без флага SwiftUI урезал бы затухание
  public var animation: Animation {
    .spring(Spring(mass: 1, stiffness: stiffness, damping: damping, allowOverDamping: true))
  }
}
