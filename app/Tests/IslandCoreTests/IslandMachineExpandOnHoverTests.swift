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
}
