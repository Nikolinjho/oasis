import Foundation
import IslandCore
import Testing

struct CodexAlertTests {
  func notice(_ threshold: Int, sound: Bool = true) -> CodexNotice {
    CodexNotice(
      details: ClaudeNotice(
        reason: .threshold(threshold), remaining: threshold, resetsAt: nil, runsOutAt: nil,
        urgent: threshold <= 5, sound: sound ? .lowBattery : nil), windowTitle: "5 часов")
  }

  @Test("Уведомления Claude и Codex ждут отдельно, отзыв Codex сохраняет Claude")
  func separateQueue() {
    var model = IslandModel(config: .user)
    model.surface = .hud(.volume, level: 0.5)
    let claude = IslandAlert.claude(notice(5).details)
    let codex = IslandAlert.codex(notice(5))
    _ = IslandMachine.reduce(&model, .alertArrived(claude))
    _ = IslandMachine.reduce(&model, .alertArrived(codex))
    #expect(model.alertQueue.count == 2)
    _ = IslandMachine.reduce(&model, .alertRetracted(.codex))
    #expect(model.alertQueue == [claude])
  }

  @Test("Обычный Codex peek убирается при входе в fullscreen, критический остаётся")
  func fullscreen() {
    var model = IslandModel(config: .user)
    model.surface = .alert(.codex(notice(25, sound: false)))
    _ = IslandMachine.reduce(&model, .fullscreenChanged(true))
    #expect(model.surface != .alert(.codex(notice(25, sound: false))))
    model.surface = .alert(.codex(notice(5)))
    _ = IslandMachine.reduce(&model, .fullscreenChanged(true))
    #expect(model.surface == .alert(.codex(notice(5))))
  }

  @Test("Новый критический порог звучит при обновлении уже показанного peek")
  func criticalUpdateSound() {
    var model = IslandModel(config: .user)
    model.surface = .alert(.codex(notice(5)))
    let effects = IslandMachine.reduce(&model, .alertArrived(.codex(notice(0))))
    #expect(effects.contains(.play(.lowBattery)))
    let repeated = IslandMachine.reduce(&model, .alertArrived(.codex(notice(0))))
    #expect(!repeated.contains(.play(.lowBattery)))
  }
}
