import Testing
@testable import IslandCore

/// Expand on hover выключен (General, Alcove 1.7.7): hover — только отклик, раскрывает клик
struct IslandMachineExpandOnHoverTests {
    static let config = IslandMachine.Config.user.applying(expandOnHover: false, hoverDuration: 0)

    static func model(_ surface: Surface, media: Bool = false) -> IslandModel {
        var model = IslandModel(config: config)
        model.surface = surface
        model.hasMedia = media
        return model
    }

    @Test("Hover без раскрытия даёт отклик и не ставит таймер", arguments: [Surface.idle, .compact, .peek])
    func hoverNudgesOnly(from: Surface) {
        var m = Self.model(from, media: from != .idle)
        let fx = IslandMachine.reduce(&m, .hoverEntered)
        #expect(m.surface == .hoverNudge(from: from))
        #expect(fx == [.cancel(.peekEnd), .animate(.hoverNudge)])
    }

    @Test("Клик по отклику раскрывает остров")
    func clickExpands() {
        var m = Self.model(.hoverNudge(from: .idle))
        let fx = IslandMachine.reduce(&m, .clicked)
        #expect(m.surface == .expanded)
        #expect(fx == [.cancel(.hoverOpen), .animate(.expand)])
    }

    @Test("Уход курсора с отклика возвращает покой")
    func leaveReturnsToRest() {
        var m = Self.model(.hoverNudge(from: .idle))
        let fx = IslandMachine.reduce(&m, .hoverExited)
        #expect(m.surface == .idle)
        #expect(fx == [.cancel(.hoverOpen), .animate(.hoverNudgeBack)])
    }

    @Test("Настройки General: задержка зажата в 0…0.6 с, темп и остальное поведение не меняются")
    func applyingSettings() {
        let base = IslandMachine.Config.user
        let slow = base.applying(expandOnHover: true, hoverDuration: 0.9)
        #expect(slow.hoverDelay == .milliseconds(600))
        #expect(slow.expandsOnHover)
        #expect(slow.timeScale == base.timeScale)
        #expect(slow.hoverOpensPlayer == base.hoverOpensPlayer)
        #expect(base.applying(expandOnHover: false, hoverDuration: -1).hoverDelay == .zero)
        #expect(base.applying(expandOnHover: true, hoverDuration: 0.3).hoverDelay == .milliseconds(300))
    }

    @Test("Не число (NaN, бесконечность) в задержке не роняет Int(): читается как 0")
    func applyingSettingsRejectsNonFiniteDuration() {
        let base = IslandMachine.Config.user
        #expect(base.applying(expandOnHover: true, hoverDuration: .nan).hoverDelay == .zero)
        #expect(base.applying(expandOnHover: true, hoverDuration: .infinity).hoverDelay == .zero)
        #expect(base.applying(expandOnHover: true, hoverDuration: -.infinity).hoverDelay == .zero)
    }

    @Test("Уход курсора с отклика над компактом возвращает компакт назад")
    func leaveFromCompactReturnsToCompact() {
        var m = Self.model(.hoverNudge(from: .compact), media: true)
        let fx = IslandMachine.reduce(&m, .hoverExited)
        #expect(m.surface == .compact)
        #expect(fx == [.cancel(.hoverOpen), .animate(.hoverNudgeBack)])
    }

    // peek не бывает состоянием покоя (m.base — либо .idle, либо .compact), поэтому и с выключенным
    // Expand on hover уход с отклика над peek схлопывает в компакт той же пружиной peekClose,
    // что и без этой настройки (см. IslandMachineHoverNudgeTests.exitNudgeFromPeek) — leave() от неё не зависит
    @Test("Уход курсора с отклика над peek возвращает в компакт, а не в peek")
    func leaveFromPeekReturnsToCompact() {
        var m = Self.model(.hoverNudge(from: .peek), media: true)
        let fx = IslandMachine.reduce(&m, .hoverExited)
        #expect(m.surface == .compact)
        #expect(fx == [.cancel(.hoverOpen), .animate(.peekClose)])
    }

    @Test("Ненулевая Hover duration с выключенным Expand on hover тоже не ставит таймер")
    func hoverNudgeWithDelayStillHasNoTimer() {
        var m = IslandModel(config: IslandMachine.Config.user.applying(expandOnHover: false, hoverDuration: 0.3))
        let fx = IslandMachine.reduce(&m, .hoverEntered)
        #expect(m.surface == .hoverNudge(from: .idle))
        #expect(fx == [.cancel(.peekEnd), .animate(.hoverNudge)])
    }

    @Test("Таймер раскрытия, оставшийся от включённой настройки, не раскрывает после её выключения")
    func staleHoverOpenTimerNoOpsAfterSettingDisabled() {
        var m = IslandModel(config: IslandMachine.Config.user.applying(expandOnHover: true, hoverDuration: 0.3))
        _ = IslandMachine.reduce(&m, .hoverEntered)
        #expect(m.surface == .hoverNudge(from: .idle))
        // настройка выключилась, пока курсор уже наводит: таймер hoverOpen остался в очереди
        m.config = m.config.applying(expandOnHover: false, hoverDuration: 0.3)
        let fx = IslandMachine.reduce(&m, .timerFired(.hoverOpen))
        #expect(fx.isEmpty)
        #expect(m.surface == .hoverNudge(from: .idle))
    }
}
